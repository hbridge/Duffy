from random import randint
import datetime
import logging
import re
import phonenumbers
from threading import Thread

from django.shortcuts import get_list_or_404

from rest_framework.generics import CreateAPIView, GenericAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.response import Response
from rest_framework.mixins import CreateModelMixin, ListModelMixin
from rest_framework import status

from peanut.settings import constants

from common.models import PhotoAction, ContactEntry, StrandInvite, User
from common.serializers import BulkContactEntrySerializer, BulkStrandInviteSerializer

from strand import notifications_util

logger = logging.getLogger(__name__)


class BulkCreateModelMixin(CreateModelMixin):
    def chunks(self, l, n):
        """ Yield successive n-sized chunks from l.
        """
        for i in xrange(0, len(l), n):
            yield l[i:i+n]

    batchSize = 1000

    """
    Either create a single or many model instances in bulk by using the
    Serializer's ``many=True`` ability from Django REST >= 2.2.5.

    .. note::
        This mixin uses the same method to create model instances
        as ``CreateModelMixin`` because both non-bulk and bulk
        requests will use ``POST`` request method.

    Pulled from: https://github.com/miki725/django-rest-framework-bulk
    """

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.DATA)

        model = serializer.bulk_model
        if serializer.is_valid():
            objects = serializer.object[serializer.bulk_key]
            
            [self.pre_save(obj) for obj in objects]

            results = list()
            for chunk in self.chunks(objects, self.batchSize):

                batchKey = randint(1,10000)
                for obj in objects:
                    obj.bulk_batch_key = batchKey

                model.objects.bulk_create(objects)

                # Only want to grab stuff from the last 10 seconds since bulk_batch_key could repeat
                dt = datetime.datetime.now() - datetime.timedelta(seconds=10)
                results.extend(model.objects.filter(bulk_batch_key = batchKey).filter(added__gt=dt))

            serializer.object[serializer.bulk_key] = results
            [self.post_save(obj, created=True) for obj in serializer.object[serializer.bulk_key]]
            
            return Response(serializer.data, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

"""
    Used to do a fast bulk update with one write to the database
"""
class BulkCreateAPIView(BulkCreateModelMixin,
                        GenericAPIView):
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)



class ContactEntryBulkAPI(BulkCreateAPIView):
    model = ContactEntry
    lookup_field = 'id'
    serializer_class = BulkContactEntrySerializer

    """
        Clean up the phone number and set it.  Should only be one number per entry

        TODO(Derek): Can this be combined with StrandInviteBulkAPI?
    """
    def pre_save(self, obj):
        logger.info("Doing a ContactEntry bulk update for user %s of number %s" % (obj.user, obj.phone_number))
        foundMatch = False      
        for match in phonenumbers.PhoneNumberMatcher(obj.phone_number, "US"):
            foundMatch = True
            obj.phone_number = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)

        if not foundMatch:
            logger.info("Parse error for contact entry")
            obj.skip = True


class StrandInviteBulkAPI(BulkCreateAPIView):
    model = StrandInvite
    lookup_field = 'id'
    serializer_class = BulkStrandInviteSerializer

    def sendNotification(self, strandInviteId):
        strandInvite = StrandInvite.objects.select_related().get(id=strandInviteId)
        msg = "%s just invited you to look at their Strand in %s" % (strandInvite.user.display_name, strandInvite.strand.photos.all()[0].location_city)
        
        if strandInvite.invited_user:
            notifications_util.sendNotification(strandInvite.invited_user, msg, constants.NOTIFICATIONS_INVITED_TO_STRAND, None)

    """
        Clean up the phone number and set it.  Should only be one number per entry

        TODO(Derek): Can this be combined with ContactEntryBulkAPI?
    """
    def pre_save(self, strandInvite):
        logger.info("Doing a StrandInvite bulk update for user %s of strand %s and number %s" % (strandInvite.user, strandInvite.strand, strandInvite.phone_number))
        foundMatch = False      
        for match in phonenumbers.PhoneNumberMatcher(strandInvite.phone_number, "US"):
            foundMatch = True
            strandInvite.phone_number = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)

        if not foundMatch:
            logger.info("Parse error for Strand Invite")
            strandInvite.skip = True
        else:
            # Found a valid phone number, now lets see if we can find a valid user for that
            try:
                user = User.objects.get(phone_number=strandInvite.phone_number)
                strandInvite.invited_user = user
            except User.DoesNotExist:
                logger.debug("Looked for %s but didn't find matching user" % (strandInvite.phone_number))

    def post_save(self, strandInvite, created):
        if created:
            print strandInvite
            thread = Thread(target = self.sendNotification, args = (strandInvite.id,))
            thread.start()
            logger.debug("Just started thread to send notification about strand invite")            
"""
    REST interface for creating new PhotoActions.

    Use a custom overload of the create method so we don't double create likes
"""
class CreatePhotoActionAPI(CreateAPIView):
    def post(self, request):
        serializer = self.get_serializer(data=request.DATA, files=request.FILES)

        if serializer.is_valid():
            obj = serializer.object
            results = PhotoAction.objects.filter(photo_id=obj.photo_id, user_id=obj.user_id, action_type=obj.action_type)

            if len(results) > 0:
                serializer = self.get_serializer(results[0])
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            else:
                return super(CreatePhotoActionAPI, self).post(request)
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


def updateStrandWithCorrectPhotoTimes(strand):
    changed = False
    for photo in strand.photos.all():
        if photo.time_taken > strand.last_photo_time:
            strand.last_photo_time = photo.time_taken
            changed = True

        if photo.time_taken < strand.first_photo_time:
            strand.first_photo_time = photo.time_taken
            changed = True
    return changed

"""
    REST interface for creating new PhotoActions.

    Use a custom overload of the create method so we don't double create likes
"""
class CreateStrandAPI(CreateAPIView):
    def post_save(self, strand, created):
        changed = updateStrandWithCorrectPhotoTimes(strand)
        if changed:
            logger.debug("Updated strand %d with new times" % (strand.id))
            strand.save()

        logger.info("Created new strand %s with users %s and photos %s" % (strand.id, strand.users.all(), strand.photos.all()))
        
class RetrieveUpdateDestroyStrandAPI(RetrieveUpdateDestroyAPIView):
    def pre_save(self, strand):
        updateStrandWithCorrectPhotoTimes(strand)

        logger.info("Updated strand %s", (strand.id))


from random import randint
import datetime
import logging
import re
import phonenumbers
from threading import Thread

from django.shortcuts import get_list_or_404
from django.db import IntegrityError

from rest_framework.generics import CreateAPIView, GenericAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.response import Response
from rest_framework.mixins import CreateModelMixin, ListModelMixin
from rest_framework import status
from rest_framework.exceptions import ParseError

from peanut.settings import constants

from common.models import ContactEntry, StrandInvite, User, Photo, Action, Strand
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
        Return back all new objects, filtering out existing if they already exist
        based on the unique fields
    """
    def getNewObjects(self, objects, model):
        newObjects = list()
        for obj in objects:
            result = self.fetchWithUniqueKeys(obj)
            if not result:
                newObjects.append(obj)

        return newObjects
        
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

        model = self.model
        if serializer.is_valid():
            objects = serializer.object[serializer.bulk_key]
            
            [self.pre_save(obj) for obj in objects]

            results = list()
            for chunk in self.chunks(objects, self.batchSize):

                batchKey = randint(1,10000)
                for obj in chunk:
                    obj.bulk_batch_key = batchKey

                try:
                    model.objects.bulk_create(chunk)
                except IntegrityError:
                    newObjects = self.getNewObjects(chunk, model)
                    model.objects.bulk_create(newObjects)

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
        foundMatch = False      
        for match in phonenumbers.PhoneNumberMatcher(obj.phone_number, "US"):
            foundMatch = True
            obj.phone_number = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)

        if not foundMatch:
            logger.info("Parse error for contact entry")
            obj.skip = True

"""
   Strand invite API
"""
class StrandInviteBulkAPI(BulkCreateAPIView):
    model = StrandInvite
    lookup_field = 'id'
    serializer_class = BulkStrandInviteSerializer

    def fetchWithUniqueKeys(self, obj):
        try:
            return self.model.objects.get(strand_id=obj.strand_id, user_id=obj.user_id, phone_number=obj.phone_number)
        except self.model.DoesNotExist:
            return None


    def sendNotification(self, strandInviteId):
        logger.debug("in sendNotification for id %s" % strandInviteId)
        strandInvite = StrandInvite.objects.select_related().get(id=strandInviteId)
        msg = "%s just invited you to look at their Strand in %s" % (strandInvite.user.display_name, strandInvite.strand.photos.all()[0].location_city)
        
        if strandInvite.invited_user:
            logger.debug("going to send %s to user id %s" % (msg, strandInvite.invited_user.id))
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
                user = User.objects.get(phone_number=strandInvite.phone_number, product_id=2)
                strandInvite.invited_user = user
            except User.DoesNotExist:
                logger.debug("Looked for %s but didn't find matching user" % (strandInvite.phone_number))

    def post_save(self, strandInvite, created):
        if created:
            thread = Thread(target = self.sendNotification, args = (strandInvite.id,))
            thread.start()
            logger.debug("Just started thread to send notification about strand invite %s" % (strandInvite.id))            


class RetrieveUpdateDestroyStrandInviteAPI(RetrieveUpdateDestroyAPIView):
    def sendNotification(self, strandInviteId):
        strandInvite = StrandInvite.objects.select_related().get(id=strandInviteId)
        msg = "%s just joined your Strand from %s" % (strandInvite.accepted_user.display_name, strandInvite.strand.photos.all()[0].location_city)
        
        logger.debug("going to send %s to user id %s" % (msg, strandInvite.user.id))
        notifications_util.sendNotification(strandInvite.user, msg, constants.NOTIFICATIONS_ACCEPTED_INVITE, None)


    def post_save(self, strandInvite, created):
        if strandInvite.accepted_user_id:
            thread = Thread(target = self.sendNotification, args = (strandInvite.id,))
            thread.start()
            logger.info("Updated strandInvite %s and started thread to send notification", (strandInvite.id))

            oldActions = list(Action.objects.filter(user=strandInvite.accepted_user, strand=strandInvite.strand).order_by("-added"))
            action = Action(user=strandInvite.accepted_user, strand=strandInvite.strand, action_type=constants.ACTION_TYPE_JOIN_STRAND)
            action.save()

            # Run through old actions to see if we need to change the timing of the join (incase the "add"
            #    action happened first).  Also remove if any old ones exist
            for oldAction in oldActions:
                # Can't join a strand more than once, just do a quick check for that
                if oldAction.action_type == action.action_type and oldAction.user == action.user:
                    action.delete()

"""
    REST interface for creating new Actions.

    Use a custom overload of the create method so we don't double create likes
"""
class CreateActionAPI(CreateAPIView):
    def post(self, request):
        serializer = self.get_serializer(data=request.DATA, files=request.FILES)

        if serializer.is_valid():
            obj = serializer.object

            results = Action.objects.filter(photo_id=obj.photo_id, user_id=obj.user_id, action_type=obj.action_type)

            if len(results) > 0:
                serializer = self.get_serializer(results[0])
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            else:
                return super(CreateActionAPI, self).post(request)
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
    REST interface for creating and editing strands

    Use a custom overload of the create method so we don't double create likes
"""
class CreateStrandAPI(CreateAPIView):
    def post_save(self, strand, created):
        changed = updateStrandWithCorrectPhotoTimes(strand)
        if changed:
            logger.debug("Updated strand %d with new times" % (strand.id))
            strand.save()

        # Now we want to create the "Added photos to a strand" Action
        try:
            user = User.objects.get(id=self.request.DATA['user_id'])
        except User.DoesNotExist:
            raise ParseError('User not found')

        if strand.shared == True:
            action = Action(user=user, strand=strand, action_type=constants.ACTION_TYPE_CREATE_STRAND)
            action.save()
            action.photos = strand.photos.all()

        # Created from is the private strand of the user.  We now want to hide it from view
        if strand.created_from_id:
            createdFromStrand = Strand.objects.get(id=strand.created_from_id)
            if createdFromStrand and createdFromStrand.user_id == user.id and createdFromStrand.shared == False:
                createdFromStrand.visible = False
                createdFromStrand.save()

        logger.info("Created new strand %s with users %s and photos %s" % (strand.id, strand.users.all(), strand.photos.all()))
        
class RetrieveUpdateDestroyStrandAPI(RetrieveUpdateDestroyAPIView):
    def pre_save(self, strand):      
        # Don't need to explicity save here since this is pre_save
        updateStrandWithCorrectPhotoTimes(strand)

        # Now we want to create the "Added photos to a strand" Action
        try:
            user = User.objects.get(id=self.request.DATA['user_id'])
        except User.DoesNotExist:
            raise ParseError('User not found')

        currentPhotoIds = Photo.getIds(strand.photos.all())

        # Find the photo ids that are in the post data but not in the strand
        newPhotoIds = list()
        for photoId in self.request.DATA['photos']:
            if photoId not in currentPhotoIds:
                newPhotoIds.append(photoId)

        if len(newPhotoIds) > 0:
            action = Action(user=user, strand=strand, action_type=constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND)
            action.save()

            action.photos = newPhotoIds






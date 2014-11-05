from random import randint
import datetime
import logging
import re
import phonenumbers
import json
from threading import Thread

from django.shortcuts import get_list_or_404
from django.db import IntegrityError
from django.db.models import Q
from django.contrib.gis.geos import Point, fromstr
from django.forms.models import model_to_dict
from django.http import HttpResponse

from rest_framework.generics import CreateAPIView, GenericAPIView, RetrieveUpdateDestroyAPIView, RetrieveUpdateAPIView
from rest_framework.response import Response
from rest_framework.mixins import CreateModelMixin, ListModelMixin
from rest_framework import status
from rest_framework.exceptions import ParseError
from rest_framework.views import APIView

from peanut.settings import constants

from common.models import ContactEntry, StrandInvite, User, Photo, Action, Strand, FriendConnection, StrandNeighbor
from common.serializers import PhotoSerializer, BulkContactEntrySerializer, BulkStrandInviteSerializer
from common import location_util, api_util

# TODO(Derek): move this to common
from arbus import image_util

from strand import notifications_util

logger = logging.getLogger(__name__)

class BasePhotoAPI(APIView):
    def jsonDictToSimple(self, jsonDict):
        ret = dict()
        for key in jsonDict:
            var = jsonDict[key]
            if type(var) is dict or type(var) is list:
                ret[key] = json.dumps(jsonDict[key])
            else:
                ret[key] = str(var)

        return ret

    """
        Fill in extra data that needs a bit more processing.
        Right now time_taken and location_point.  Both will look at the file exif data if
          we don't have iphone metadata
    """
    def populateExtraData(self, photo):
        if not photo.location_point:
            lat, lon, accuracy = location_util.getLatLonAccuracyFromExtraData(photo, True)

            if (lat and lon):
                photo.location_point = fromstr("POINT(%s %s)" % (lon, lat))
                photo.location_accuracy_meters = accuracy

            elif accuracy and accuracy < photo.location_accuracy_meters:
                photo.location_point = fromstr("POINT(%s %s)" % (lon, lat))
                photo.location_accuracy_meters = accuracy

                if photo.strand_evaluated:
                    photo.strand_needs_reeval = True
                    
            elif accuracy and accuracy >= photo.location_accuracy_meters:
                logger.debug("For photo %s, Got new accuracy but was the same or greater:  %s  %s" % (photo.id, accuracy, photo.location_accuracy_meters))
        
        if not photo.time_taken:
            photo.time_taken = image_util.getTimeTakenFromExtraData(photo, True)
                    
        # Bug fix for bad data in photo where date was before 1900
        # Initial bug was from a photo in iPhone 1, guessing at the date
        if (photo.time_taken and photo.time_taken.date() < datetime.date(1900, 1, 1)):
            logger.debug("Found a photo with a date earlier than 1900: %s" % (photo.id))
            photo.time_taken = datetime.date(2007, 9, 1)
                
        return photo

    def populateExtraDataForPhotos(self, photos):
        for photo in photos:
            self.populateExtraData(photo)
        return photos

    def simplePhotoSerializer(self, photoData):
        photoData["user_id"] = photoData["user"]
        del photoData["user"]

        if "taken_with_strand" in photoData:
            photoData["taken_with_strand"] = int(photoData["taken_with_strand"])

        if "time_taken" in photoData:
            photoData["time_taken"] = datetime.datetime.strptime(photoData["time_taken"], "%Y-%m-%dT%H:%M:%SZ")

        if "local_time_taken" in photoData:
            photoData["local_time_taken"] = datetime.datetime.strptime(photoData["local_time_taken"], "%Y-%m-%dT%H:%M:%SZ")

        if "id" in photoData:
            photoId = int(photoData["id"])

            if photoId == 0:
                del photoData["id"]
            else:
                photoData["id"] = photoId

        photo = Photo(**photoData)
        return photo


class PhotoAPI(BasePhotoAPI):
    def getObject(self, photoId):
        try:
            return Photo.objects.get(id=photoId)
        except Photo.DoesNotExist:
            logger.info("Photo id does not exist: %s   returning 404" % (photoId))
            raise Http404

    def get(self, request, photoId=None, format=None):
        if (photoId):
            photo = self.getObject(photoId)
            serializer = PhotoSerializer(photo)
            return Response(serializer.data)
        else:
            pass

    
    def patch(self, request, photoId, format=None):
        photo = self.getObject(photoId)

        photoData = request.DATA
        serializer = PhotoSerializer(photo, data=photoData, partial=True)

        if serializer.is_valid():
            serializer.save()

            Thread(target=threadedSendNotifications, args=(userIds,)).start()
            return Response(serializer.data)
        else:
            logger.info("Photo serialization failed, returning 400.  Errors %s" % (serializer.errors))
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


    def put(self, request, photoId, format=None):
        photo = self.getObject(photoId)

        if "photo" in request.DATA:
            jsonDict = json.loads(request.DATA["photo"])
            photoData = self.jsonDictToSimple(jsonDict)
        else:
            photoData = request.DATA

        serializer = PhotoSerializer(photo, data=photoData, partial=True)

        if serializer.is_valid():
            # This will look at the uploaded metadata or exif data in the file to populate more fields
            photo = self.populateExtraData(serializer.object)
                        
            image_util.handleUploadedImage(request, serializer.data["file_key"], serializer.object)
            Photo.bulkUpdate(photo, ["location_point", "strand_needs_reeval", "location_accuracy_meters", "full_filename", "thumb_filename", "metadata", "time_taken"])

            logger.info("Successfully did a put for photo %s" % (photo.id))
            return Response(PhotoSerializer(photo).data)
        else:
            logger.info("Photo serialization failed, returning 400.  Errors %s" % (serializer.errors))
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def post(self, request, format=None):
        serializer = PhotoSerializer(data=request.DATA, partial=True)
        if serializer.is_valid():
            try:
                serializer.save()
                image_util.handleUploadedImage(request, serializer.data["file_key"], serializer.object)

                # This will look at the uploaded metadata or exif data in the file to populate more fields
                photo = self.populateExtraData(serializer.object)
                Photo.bulkUpdate(photo, ["location_point", "strand_needs_reeval", "location_accuracy_meters", "full_filename", "thumb_filename", "metadata", "time_taken"])

                logger.info("Successfully did a post for photo %s" % (photo.id))
                return Response(PhotoSerializer(photo).data)
            except IntegrityError:
                logger.error("IntegrityError")
                Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, photoId, format=None):
        # TODO: Derek. Remove this hack that currently handles repetitive requests to delete same photo
        try:
            photo = Photo.objects.get(id=photoId)
        except Photo.DoesNotExist:
            logger.info("Photo id does not exist in delete: %s   returning 204" % (photoId))
            return Response(status=status.HTTP_204_NO_CONTENT)

        userId = photo.user_id

        photo.delete()

        logger.info("DELETE - User %s deleted photo %s" % (userId, photoId))
        return Response(status=status.HTTP_204_NO_CONTENT)

class PhotoBulkAPI(BasePhotoAPI):
    def populateTimezonesForPhotos(self, photos):
        timezonerBaseUrl = "http://localhost:8234/timezone?"
        
        params = list()
        photosNeedingTimezone = list()
        for photo in photos:
            if not photo.time_taken and photo.local_time_taken and photo.location_point:
                photosNeedingTimezone.append(photo)
                params.append("ll=%s,%s" % (photo.location_point.y, photo.location_point.x))
        timezonerParams = '&'.join(params)

        if len(photosNeedingTimezone) > 0:
            timezonerUrl = "%s%s" % (timezonerBaseUrl, timezonerParams)

            logger.info("requesting timezones for %s photos" % len(photosNeedingTimezone))
            timezonerResultJson = urllib2.urlopen(timezonerUrl).read()
            
            if (timezonerResultJson):
                timezonerResult = json.loads(timezonerResultJson)
                for i, photo in enumerate(photosNeedingTimezone):
                    timezoneName = timezonerResult[i]
                    if not timezoneName:
                        logger.error("got no timezone with lat:%s lon:%s, setting to Eastern" % (photo.location_point.y, photo.location_point.x))
                        tzinfo = pytz.timezone('US/Eastern')
                    else:   
                        tzinfo = pytz.timezone(timezoneName)
                            
                    localTimeTaken = photo.local_time_taken.replace(tzinfo=tzinfo)
                    photo.time_taken = localTimeTaken.astimezone(pytz.timezone("UTC"))
                logger.info("Successfully updated timezones for %s photos" % len(photosNeedingTimezone))

    def post(self, request, format=None):
        response = list()

        startTime = datetime.datetime.now()

        objsToCreate = list()
        objsToUpdate = list()

        batchKey = randint(1,10000)  
        if "patch_photos" in request.DATA:
            response = dict()
            photosData = request.DATA["patch_photos"]

            # fetch hashes for these photos to check for dups if this is a new install
            try:
                user = User.objects.get(id=photosData[0]['user'])
            except User.DoesNotExist:
                return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")  

            logger.info("Got request for bulk patch update with %s photos and %s files from user %s" % (len(photosData), len(request.FILES), user.id))

            for photoData in photosData:
                photoData = self.jsonDictToSimple(photoData)
                photoData["bulk_batch_key"] = batchKey

                photo = self.simplePhotoSerializer(photoData)
                objsToUpdate.append(photo)
                
            Photo.bulkUpdate(objsToUpdate, ['install_num', 'iphone_faceboxes_topleft'])
            objsToUpdate = Photo.objects.filter(id__in=Photo.getIds(objsToUpdate))

            response['patch_photos'] = [model_to_dict(photo) for photo in objsToUpdate]

            logger.info("Successfully processed %s photos for user %s" % (len(objsToUpdate), user.id))
            return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json", status=201)


        elif "bulk_photos" in request.DATA:
            photosData = json.loads(request.DATA["bulk_photos"])

            # fetch hashes for these photos to check for dups if this is a new install
            try:
                user = User.objects.get(id=photosData[0]['user'])
            except User.DoesNotExist:
                return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")  

            logger.info("Got request for bulk photo update with %s photos and %s files from user %s" % (len(photosData), len(request.FILES), user.id))
            
            for photoData in photosData:
                photoData = self.jsonDictToSimple(photoData)
                photoData["bulk_batch_key"] = batchKey

                photo = self.simplePhotoSerializer(photoData)

                self.populateExtraData(photo)

                #if photo.iphone_hash in existingPhotosByHash:
                #   existingPhoto = existingPhotosByHash[photo.iphone_hash]
                #   existingPhoto.file_key = photo.file_key

                #   objsToUpdate.append(existingPhoto)
                if photo.id:
                    objsToUpdate.append(photo)
                else:
                    objsToCreate.append(photo)

            """
                hashes = list()
                existingPhotosByHash = dict()
                if user.install_num > 0:
                    for photoData in photosData:
                        hashes.append(photoData['iphone_hash'])
                    existingPhotos = Photo.objects.filter(user = user, hashes__in=hashes)
                    for photo in existingPhotos:
                        existingPhotosByHash[photo.iphone_hash] = photo
            """
                
            Photo.objects.bulk_create(objsToCreate)

            # Only want to grab stuff from the last 60 seconds since bulk_batch_key could repeat
            dt = datetime.datetime.now() - datetime.timedelta(seconds=60)
            createdPhotos = list(Photo.objects.filter(bulk_batch_key = batchKey).filter(updated__gt=dt))

            allPhotos = list()
            allPhotos.extend(createdPhotos)
            
            # Fetch real db objects instead of using the serialized ones.  Only doing this with things
            #   that are already created
            objsToUpdate = Photo.objects.filter(id__in=Photo.getIds(objsToUpdate))

            allPhotos.extend(objsToUpdate)
            # Now that we've created the images in the db, we need to deal with any uploaded images
            #   and fill in any EXIF data (time_taken, gps, etc)
            if len(allPhotos) > 0:
                logger.info("Successfully created %s entries in db, and had %s existing ... now processing photos" % (len(createdPhotos), len(objsToUpdate)))

                # This will move the uploaded image over to the filesystem, and create needed thumbs
                numImagesProcessed = image_util.handleUploadedImagesBulk(request, allPhotos)

                if numImagesProcessed > 0:
                    # These are all the fields that we might want to update.  List of the extra fields from above
                    # TODO(Derek):  Probably should do this more intelligently
                    Photo.bulkUpdate(allPhotos, ["full_filename", "thumb_filename"])
                    logger.info("Doing another update for created photos because %s photos had images" % (numImagesProcessed))
            else:
                logger.error("For some reason got back 0 photos created.  Using batch key %s at time %s", batchKey, dt)
            
            response = [model_to_dict(photo) for photo in allPhotos]

            logger.info("Successfully processed %s photos for user %s" % (len(response), user.id))
            return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json", status=201)
        else:
            logger.error("Got request with no bulk_photos, returning 400")
            return HttpResponse(json.dumps({"bulk_photos": "Missing key"}), content_type="application/json", status=400)


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

    re_pattern = re.compile(u'[^\u0000-\uD7FF\uE000-\uFFFF]', re.UNICODE)

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

        # This will filter out 3-byte and up unicode strings.
        obj.name = self.re_pattern.sub(u'\uFFFD', obj.name) 

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

class RetrieveUpdateDestroyStrandInviteAPI(RetrieveUpdateDestroyAPIView):
    def post_save(self, strandInvite, created):
        if strandInvite.accepted_user_id:
            oldActions = list(Action.objects.filter(user=strandInvite.accepted_user, strand=strandInvite.strand).order_by("-added"))
            action = Action(user=strandInvite.accepted_user, strand=strandInvite.strand, action_type=constants.ACTION_TYPE_JOIN_STRAND)
            action.save()

            # Run through old actions to see if we need to change the timing of the join (incase the "add"
            #    action happened first).  Also remove if any old ones exist
            for oldAction in oldActions:
                # Can't join a strand more than once, just do a quick check for that
                if oldAction.action_type == action.action_type and oldAction.user == action.user:
                    action.delete()

            FriendConnection.addNewConnections(strandInvite.accepted_user, strandInvite.strand.users.all())
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

class RetrieveUpdateUserAPI(RetrieveUpdateAPIView):
    def pre_save(self, user):
        if self.request.DATA['build_id'] and self.request.DATA['build_number']:
            # if last_build_info is empty or if either build_id or build_number is not in last_build_info
            #    update last_build_info
            buildId = self.request.DATA['build_id']
            buildNum = self.request.DATA['build_number']
            if ((not user.last_build_info) or 
                buildId not in user.last_build_info or 
                str(buildNum) not in user.last_build_info):
                user.last_build_info = "%s-%s" % (buildId, buildNum)
                logger.info("Build info updated to %s for user %s" % (user.last_build_info, user.id))

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
    def pre_save(self, strand):
        self.request.DATA['photos'] = list(set(self.request.DATA['photos']))
        self.request.DATA['users'] = list(set(self.request.DATA['users']))

    def post_save(self, strand, created):
        if created:
            changed = updateStrandWithCorrectPhotoTimes(strand)
            if changed:
                logger.debug("Updated strand %d with new times" % (strand.id))
                strand.save()

            # Now we want to create the "Added photos to a strand" Action
            try:
                user = User.objects.get(id=self.request.DATA['user_id'])
            except User.DoesNotExist:
                raise ParseError('User not found')

            if strand.private == False:
                action = Action(user=user, strand=strand, action_type=constants.ACTION_TYPE_CREATE_STRAND)
                action.save()
                action.photos = strand.photos.all()

            # Created from is the private strand of the user.  We now want to hide it from view

            # Go through all the private strands that have any photos we're contributing
            #   and mark them as such
            privateStrands = Strand.objects.filter(photos__id__in=self.request.DATA['photos'], private=True, user=user)
            newStrandNeighbors = list()
            for privateStrand in privateStrands:
                privateStrand.suggestible = False
                privateStrand.contributed_to_id = strand.id
                privateStrand.save()

                # Next, add in strand Neighbor entries for all the private strands the created from one had
                #  to the new public one
                """
                strandNeighbors = StrandNeighbor.objects.filter(Q(strand_1 = privateStrand) | Q(strand_2 = privateStrand))
                for strandNeighbor in strandNeighbors:
                    if strandNeighbor.strand_1_id != privateStrand.id:
                        # The newly created strand will always have the higher id since it was just created
                        newStrandNeighbors.append(StrandNeighbor(strand_1=strandNeighbor.strand_1, strand_2=strand))
                    else:
                        newStrandNeighbors.append(StrandNeighbor(strand_1=strandNeighbor.strand_2, strand_2=strand))
                """
            if len(newStrandNeighbors) > 0:
                StrandNeighbor.objects.bulk_create(newStrandNeighbors)
                    
            logger.info("Created new strand %s with users %s and photos %s and neighborRows %s" % (strand.id, strand.users.all(), strand.photos.all(), newStrandNeighbors))
            
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
        currentUserIds = User.getIds(strand.users.all())

        # Find the photo ids that are in the post data but not in the strand
        newPhotoIds = list()
        for photoId in self.request.DATA['photos']:
            if photoId not in currentPhotoIds:
                newPhotoIds.append(photoId)

        # Find the photo ids that are in the post data but not in the strand
        newUserIds = list()
        for userId in self.request.DATA['users']:
            if userId not in currentUserIds:
                newUserIds.append(userId)


        self.request.DATA['photos'] = list(set(newPhotoIds))
        self.request.DATA['users'] = list(set(newUserIds))

        if len(newPhotoIds) > 0:
            # Go through all the private strands that have any photos we're contributing
            #   and mark them as such
            privateStrands = Strand.objects.filter(photos__id__in=newPhotoIds, private=True, user=user)

            for privateStrand in privateStrands:
                privateStrand.suggestible = False
                privateStrand.contributed_to_id = strand.id
                privateStrand.save()

            action = Action(user=user, strand=strand, action_type=constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND)
            action.save()
            action.photos = newPhotoIds 



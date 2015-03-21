from random import randint
import datetime
import logging
import re
import phonenumbers
import json
from threading import Thread
import dateutil.parser
import copy
import string

from django.shortcuts import get_list_or_404
from django.db import IntegrityError
from django.db.models import Q
from django.contrib.gis.geos import Point, fromstr
from django.forms.models import model_to_dict
from django.http import Http404
from django.http import HttpResponse

from rest_framework.generics import CreateAPIView, GenericAPIView, RetrieveUpdateDestroyAPIView, RetrieveUpdateAPIView
from rest_framework.response import Response
from rest_framework.mixins import CreateModelMixin, ListModelMixin
from rest_framework import status
from rest_framework.exceptions import ParseError
from rest_framework.views import APIView

from peanut.settings import constants

from common.models import ContactEntry, User, Photo, Action, Strand, FriendConnection, StrandNeighbor, ShareInstance
from common.serializers import LimitedUserSerializer, PhotoSerializer, BulkContactEntrySerializer, BulkShareInstanceSerializer, ShareInstanceSerializer, BulkUserSerializer, BulkFriendConnectionSerializer
from common import location_util, api_util

from async import two_fishes, stranding, similarity, popcaches, friending, suggestion_notifications, notifications

# TODO(Derek): move this to common
from arbus import image_util

from strand import notifications_util, strands_util, users_util

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

        if "saved_with_swap" in photoData:
            photoData["saved_with_swap"] = int(photoData["saved_with_swap"])

        if "time_taken" in photoData:
            timeStr = photoData["time_taken"].translate(None, 'apm ')
            try:
                photoData["time_taken"] = dateutil.parser.parse(timeStr)
            except ValueError:
                logger.error("Caught a ValueError in the REST photos api.  %s date was invalid.  Setting to Sept 2007 for photo %s and user %s.  You might want to manually edit it and set strand_evaluated to False" % (timeStr, photoData["id"], photoData["user_id"]))
                photoData["time_taken"] = datetime.datetime(2007, 9, 1)

        if "local_time_taken" in photoData:
            timeStr = photoData["time_taken"].translate(None, 'apm ')
            photoData["local_time_taken"] = dateutil.parser.parse(timeStr)

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
            logger.warn("Had a request to get photo id %s and didn't find." % photoId)
            raise Http404

    
    def patch(self, request, photoId, format=None):
        photo = self.getObject(photoId)

        photoData = request.DATA
        serializer = PhotoSerializer(photo, data=photoData, partial=True)

        if serializer.is_valid():
            serializer.save()

            notifications.sendRefreshFeedToUserIds.delay(userIds)
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

    # This finds the first dup that looks reasonable for us to merge in.
    # First look for one which already has the same filekey.  After that, do the highest install_num
    def getDupPhoto(self, photo, existingPhotos):
        existingPhotos = sorted(existingPhotos, key=lambda x: x.install_num, reverse=True)
        for existingPhoto in existingPhotos:
            if existingPhoto.file_key == photo.file_key or existingPhoto.time_taken == photo.time_taken:
                return existingPhoto
        return None

    def updateCacheStateForPhotos(self, user, photos):
        privateStrands = Strand.objects.filter(user=user).filter(private=True).filter(photos__in=Photo.getIds(photos))
        if len(privateStrands) > 0:
            for strand in privateStrands:
                strand.cache_dirty = True
            Strand.bulkUpdate(privateStrands, ['cache_dirty'])
            logger.debug("Set strands %s to cache_dirty" % privateStrands)

        shareInstances = ShareInstance.objects.filter(photo_id__in=Photo.getIds(photos))
        if len(shareInstances) > 0:
            for shareInstance in shareInstances:
                shareInstance.cache_dirty = True
            ShareInstance.bulkUpdate(shareInstances, ['cache_dirty'])
            logger.debug("Setting share instances %s to cache_dirty" % shareInstances)

        if len(privateStrands) > 0:
            popcaches.processPrivateStrandIds.delay(Strand.getIds(privateStrands))

        if len(shareInstances) > 0:
            popcaches.processInboxIds.delay(ShareInstance.getIds(shareInstances))

    def post(self, request, format=None):
        response = list()

        startTime = datetime.datetime.now()

        objsToCreate = list()
        objsToUpdate = list()

        batchKey = randint(1,10000)  
        """
            Right now patch photos only patches the following fields:
            install_num
            iphone_faceboxes_topleft
        """
        if "patch_photos" in request.DATA:
            response = dict()
            photosData = request.DATA["patch_photos"]

            # fetch hashes for these photos to check for dups if this is a new install
            try:
                user = User.objects.get(id=photosData[0]['user'])
            except User.DoesNotExist:
                return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")  

            logger.info("Got request for bulk patch update with %s photos and %s files from user %s" % (len(photosData), len(request.FILES), user.id))

            dataByPhotoId = dict()
            for photoData in photosData:
                photoData = self.jsonDictToSimple(photoData)

                dataByPhotoId[int(photoData["id"])] = photoData

            # Fetch from server because we need to get the most recent values
            photosToUpdate = Photo.objects.filter(id__in=dataByPhotoId.keys())
            requireClientRefresh = False

            for photo in photosToUpdate:
                if photo.id in dataByPhotoId:
                    if "install_num" in dataByPhotoId[photo.id]:
                        photo.install_num = int(dataByPhotoId[photo.id]["install_num"])
                    if "iphone_faceboxes_topleft" in dataByPhotoId[photo.id]:
                        photo.iphone_faceboxes_topleft = dataByPhotoId[photo.id]["iphone_faceboxes_topleft"]
                        requireClientRefresh = True
                else:
                    logger.error("Got id %s which isn't in the data which came in %s" % (photo.id, photosData))
            Photo.bulkUpdate(photosToUpdate, ['install_num', 'iphone_faceboxes_topleft'])

            response['patch_photos'] = [model_to_dict(photo) for photo in photosToUpdate]

            photosDeleted = list()
            for photo in photosToUpdate:
                if int(photo.install_num) == -1:
                    photosDeleted.append(photo)

            self.updateCacheStateForPhotos(user, photosDeleted)

            if requireClientRefresh:
                notifications.sendRefreshFeedToUserIds.delay([user.id])

            logger.info("Successfully processed %s photos for user %s" % (len(photosToUpdate), user.id))
            return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json", status=201)


        elif "bulk_photos" in request.DATA:
            photosData = json.loads(request.DATA["bulk_photos"])

            # fetch hashes for these photos to check for dups if this is a new install
            try:
                user = User.objects.get(id=photosData[0]['user'])
            except User.DoesNotExist:
                return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")  

            logger.info("Got request for bulk photo update with %s photos and %s files from user %s" % (len(photosData), len(request.FILES), user.id))
            
            existingPhotosByHash = dict()
            if user.install_num > 0 and len(request.FILES) == 0:
                logger.info("It appears user %s has a new install, fetching existing photos" % (user.id))
                existingPhotos = Photo.objects.filter(user = user, install_num__lte=user.install_num)
                for photo in existingPhotos:
                    if photo.iphone_hash not in existingPhotosByHash:
                        existingPhotosByHash[photo.iphone_hash] = list()
                    existingPhotosByHash[photo.iphone_hash].append(photo)
            copyOfExistingPhotosByHash = copy.deepcopy(existingPhotosByHash)
                
            for photoData in photosData:
                photoData = self.jsonDictToSimple(photoData)
                photoData["bulk_batch_key"] = batchKey
                photoData["install_num"] = user.install_num

                photo = self.simplePhotoSerializer(photoData)

                self.populateExtraData(photo)

                # If we see that this photo's hash already exists then 
                if photo.iphone_hash in existingPhotosByHash:
                    existingPhoto = self.getDupPhoto(photo, existingPhotosByHash[photo.iphone_hash])

                    if existingPhoto:
                        existingPhoto.file_key = photo.file_key
                        existingPhoto.install_num = user.install_num

                        logger.debug("Uploaded photo found with same hash as existing, setting to id %s and filekey %s for hash %s" % (existingPhoto.id, existingPhoto.file_key, existingPhoto.iphone_hash))
                        objsToUpdate.append(existingPhoto)
                        existingPhotosByHash[photo.iphone_hash].remove(existingPhoto)
                    else:
                        objsToCreate.append(photo)
                        logger.debug("Uploaded photo found with same hash %s as some existing, but different time_taken %s, creating new" % (photo.iphone_hash, photo.time_taken))
                    
                elif photo.id:
                    objsToUpdate.append(photo)
                else:
                    # Triple check that we don't have an id for this object
                    if hasattr(photo, 'id'):
                        logger.debug("New photo had id %s, removing" % photo.id)
                        photo.id = None
                    objsToCreate.append(photo)
            
            # These are all the photos we're going to return back to the client, all should have ids
            allPhotos = list()

            # These are used to deal with dups that occur with photos to be created
            objsToCreateAgain = list()
            objsFoundToMatchExisting = list()
                
            try:
                Photo.objects.bulk_create(objsToCreate)
            except IntegrityError:
                logger.info("Got IntegrityError on bulk upload for user %s on %s photos" % (user.id, len(objsToCreate)))
                # At this point, we tried created some rows that have the same user_id - hash - file_key
                # This probably means we're dealing with a request the server already processed
                # but the client didn't get back.  So for each photo we think we should create, see if the
                # exact record (hash, file_key) exists and return that id.
                hashes = [obj.iphone_hash for obj in objsToCreate]

                existingPhotos = Photo.objects.filter(user = user, iphone_hash__in=hashes)

                for objToCreate in objsToCreate:
                    foundMatch = False
                    for photo in existingPhotos:
                        if photo.iphone_hash == objToCreate.iphone_hash and photo.file_key == objToCreate.file_key:
                            # We found an exact photo match, so just make sure we return this entry to the client
                            allPhotos.append(photo)
                            objsFoundToMatchExisting.append(photo)
                            foundMatch = True
                            logger.debug("Found match on photo %s, going to return that" % (photo.id))
                    if not foundMatch:
                        objsToCreateAgain.append(objToCreate)
                        logger.debug("Didn't find match on photo with hash %s and file_key %s, going to try to create again" % (objToCreate.iphone_hash, objToCreate.file_key))

                # This call should now not barf because we've filtered out all the existing photos
                Photo.objects.bulk_create(objsToCreateAgain)
            except ValueError:
                logger.warning("Got value error when trying to process:")
                for objToCreate in objsToCreate:
                    logger.warning("%s" % objsToCreate)

            # Only want to grab stuff from the last 60 seconds since bulk_batch_key could repeat
            dt = datetime.datetime.now() - datetime.timedelta(seconds=60)
            createdPhotos = list(Photo.objects.filter(bulk_batch_key = batchKey).filter(updated__gt=dt))

            allPhotos.extend(createdPhotos)
            
            # Now bulk update photos that already exist, this could happen during re-install
            if len(objsToUpdate) > 0:
                Photo.bulkUpdate(objsToUpdate, ['file_key', 'install_num'])
                # Best to just do a fresh fetch from the db
                objsToUpdate = Photo.objects.filter(id__in=Photo.getIds(objsToUpdate))
                allPhotos.extend(objsToUpdate)
                self.updateCacheStateForPhotos(user, objsToUpdate)


            
            # Now that we've created the images in the db, we need to deal with any uploaded images
            #   and fill in any EXIF data (time_taken, gps, etc)
            if len(allPhotos) > 0:
                logger.info("Successfully created %s entries in db, had %s existing, matched up %s and had to create a second time %s ... now processing photos" % (len(createdPhotos), len(objsToUpdate), len(objsFoundToMatchExisting), len(objsToCreateAgain)))

                # This will move the uploaded image over to the filesystem, and create needed thumbs
                numImagesProcessed = image_util.handleUploadedImagesBulk(request, allPhotos)

                if numImagesProcessed > 0:
                    # These are all the fields that we might want to update.  List of the extra fields from above
                    # TODO(Derek):  Probably should do this more intelligently
                    Photo.bulkUpdate(allPhotos, ["full_filename", "thumb_filename"])
                    logger.info("Doing another update for created photos because %s photos had images" % (numImagesProcessed))
                    self.updateCacheStateForPhotos(user, allPhotos)
            else:
                logger.error("For some reason got back 0 photos created.  Using batch key %s at time %s", batchKey, dt)
            
            # Async tasks
            ids = Photo.getIds(allPhotos)
            if len(ids) > 0:
                two_fishes.processIds.delay(ids)
                stranding.processIds.delay(ids)

                # Temporarily remove until we can get it working
                #similarity.processIds.delay(ids)

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
    def getNewAndExistingObjects(self, objects):
        newObjects = list()
        existingObjects = list()
        for obj in objects:
            result = self.fetchWithUniqueKeys(obj)
            if not result:
                newObjects.append(obj)
            else:
                existingObjects.append(result)

        return newObjects, existingObjects
        
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
            manyToManyFieldData = dict()
            if hasattr(self, 'many_to_many_field'):
                # when we have a many to many field, we have to go through and create a lookup table
                # from the raw data (with the info) to a unique key per object
                objects = list()
                count = 0
                for rawData in request.DATA[serializer.bulk_key]:
                    subSerializer = self.sub_serializer(rawData)

                    if subSerializer.is_valid():
                        manyToManyFieldData[count] = rawData[self.many_to_many_field]
                        subSerializer.object.mtm_key = count
                        subSerializer.object.mtm_data = rawData[self.many_to_many_field]
                        objects.append(subSerializer.object)

                        count += 1
            else:
                objects = serializer.object[serializer.bulk_key]

            results = list()

            toCreateObjects = list()
            for obj in objects:
                self.pre_save(obj)
                if hasattr(obj, 'skip') and obj.skip:
                    results.append(obj)
                elif hasattr(obj, 'do_not_create') and obj.do_not_create:
                    continue
                else:
                    toCreateObjects.append(obj)
            
            for chunk in self.chunks(toCreateObjects, self.batchSize):

                batchKey = randint(1,10000)
                for obj in chunk:
                    obj.bulk_batch_key = batchKey

                try:
                    model.objects.bulk_create(chunk)
                except IntegrityError:
                    newObjects, existingObjects = self.getNewAndExistingObjects(chunk)
                    model.objects.bulk_create(newObjects)
                    results.extend(existingObjects)

                # Only want to grab stuff from the last 10 seconds since bulk_batch_key could repeat
                dt = datetime.datetime.now() - datetime.timedelta(seconds=10)
                results.extend(model.objects.filter(bulk_batch_key = batchKey).filter(added__gt=dt))

            if hasattr(self, 'many_to_many_field'):
                for obj in results:
                    mtmField = getattr(obj, self.many_to_many_field)
                    for data in manyToManyFieldData[obj.mtm_key]:
                        mtmField.add(data)
                                        
            serializer.object[serializer.bulk_key] = results

            [self.post_save(obj, created=True) for obj in results]
            
            if "post_save_bulk" in dir(self):
                self.post_save_bulk(results)
                
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
    """
    def pre_save(self, obj):
        foundMatch = False

        if 'user_id' in self.request.DATA:
            region_code = users_util.getRegionCodeForUser(self.request.DATA['user_id'])
        else:
            region_code = 'US'

        phoneNum = filter(lambda x: x in string.printable, obj.phone_number.encode('utf-8'))

        for match in phonenumbers.PhoneNumberMatcher(phoneNum, region_code):
            foundMatch = True
            obj.phone_number = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)

        if not foundMatch:
            logger.info("Parse error for contact entry")
            obj.skip = True

        # This will filter out 3-byte and up unicode strings.
        obj.name = self.re_pattern.sub(u'\uFFFD', obj.name)

    def post_save_bulk(self, objs):
        if len(objs) > 0:
            friending.processIds.delay(ContactEntry.getIds(objs))


class CreateFriendConnectionAPI(BulkCreateAPIView):
    model = FriendConnection
    lookup_field = 'id'
    serializer_class = BulkFriendConnectionSerializer

    def fetchWithUniqueKeys(self, obj):
        try:
            return self.model.objects.get(user_1_id=obj.user_1_id, user_2_id=obj.user_2_id)
        except self.model.DoesNotExist:
            return None

    def post_save_bulk(self, objs):
        userIds = set()
        actionIdsToNotify = list()
        for obj in objs:
            userIds.add(obj.user_1_id)
            userIds.add(obj.user_2_id)

            # TODO: Probably should be turned into a bulkcreate at some point.
            action = Action.objects.create(user_id=obj.user_1_id, action_type=constants.ACTION_TYPE_ADD_FRIEND, text='added you as a friend', target_user_id=obj.user_2_id)
            actionIdsToNotify.append(action.id)

        notifications.sendAddFriendNotificationFromActions.delay(actionIdsToNotify)
        for userId in userIds:
            suggestion_notifications.processUserId.delay(userId)


def getBuildNumForUser(user):
    if user.last_build_info:
        return int(user.last_build_info.split('-')[1])
    else:
        return 4000

class UsersBulkAPI(BulkCreateAPIView):
    model = User
    lookup_field = 'id'
    serializer_class = BulkUserSerializer

    def fetchWithUniqueKeys(self, obj):
        try:
            return self.model.objects.get(phone_number=obj.phone_number, product_id=obj.product_id)
        except self.model.DoesNotExist:
            return None

    """
        Clean up the phone number and set it.  Should only be one number per entry

        TODO(Derek): Can this be combined with ContactEntryBulkAPI?
    """
    def pre_save(self, obj):
        foundMatch = False

        phoneNum = filter(lambda x: x in string.printable, obj.phone_number.encode('utf-8'))

        if 'user_id' in self.request.DATA:
            region_code = users_util.getRegionCodeForUser(self.request.DATA['user_id'])
        else:
            region_code = 'US'

        matches = phonenumbers.PhoneNumberMatcher(phoneNum, region_code)

        for match in matches:
            foundMatch = True
            obj.phone_number = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)
            
        if not foundMatch:
            logger.error("Parse error for new user entry: %s" % obj.phone_number)
            obj.skip = True

    def post_save(self, user, created):
        if created:
            if 'user_id' in self.request.DATA:
                user.created_by = int(self.request.DATA['user_id'])
                user.save()
            users_util.initNewUser(user, False, None)

"""
    REST interface for creating new Actions.

    Use a custom overload of the create method so we don't double create likes
"""
class CreateActionAPI(CreateAPIView):
    def post(self, request):
        serializer = self.get_serializer(data=request.DATA, files=request.FILES)

        if serializer.is_valid():
            obj = serializer.object

            # if it's a comment, then allow multiple on the same photo
            if (obj.action_type == constants.ACTION_TYPE_COMMENT):
                if obj.strand:
                    for user in obj.strand.users.all():
                        if user.id != obj.user_id:
                            msg = "%s: %s" % (obj.user.display_name, obj.text)
                            logger.debug("going to send %s to user id %s" % (msg, user.id))
                            customPayload = {'strand_id': obj.strand_id, 'id': obj.photo_id}
                            notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_PHOTO_COMMENT, customPayload)
                elif obj.share_instance:
                    for user in obj.share_instance.users.all():
                        if user.id != obj.user_id:
                            msg = "%s: %s" % (obj.user.display_name, obj.text)
                            logger.debug("going to send %s to user id %s" % (msg, user.id))
                            customPayload = {'share_instance_id': obj.share_instance_id, 'id': obj.photo_id}
                            notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_PHOTO_COMMENT, customPayload)

                return super(CreateActionAPI, self).post(request)
            elif (obj.action_type == constants.ACTION_TYPE_FAVORITE):
                if obj.photo.user_id != obj.user_id:
                        msg = "%s just liked your photo" % (obj.user.display_name)
                        logger.debug("going to send %s to user id %s" % (msg, obj.photo.user_id))
                        customPayload = {'share_instance_id': obj.share_instance_id, 'id': obj.photo_id}
                        notifications_util.sendNotification(obj.photo.user, msg, constants.NOTIFICATIONS_PHOTO_FAVORITED_ID, customPayload)
                if obj.strand:
                    results = Action.objects.filter(photo_id=obj.photo_id, strand_id=obj.strand_id, user_id=obj.user_id, action_type=obj.action_type)
                elif obj.share_instance:
                    results = Action.objects.filter(photo_id=obj.photo_id, share_instance_id=obj.share_instance_id, user_id=obj.user_id, action_type=obj.action_type)

                if len(results) > 0:
                    serializer = self.get_serializer(results[0])
                    return Response(serializer.data, status=status.HTTP_201_CREATED)
                else:
                    return super(CreateActionAPI, self).post(request)
            elif (obj.action_type == constants.ACTION_TYPE_PHOTO_EVALUATED):
                if obj.strand:
                    strands_util.checkStrandForAllPhotosEvaluated(obj.strand)
                if obj.user_id == obj.photo.user_id:
                    obj.photo.owner_evaluated = True
                    obj.photo.save()
                return super(CreateActionAPI, self).post(request)
            else:
                return super(CreateActionAPI, self).post(request)

        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
    def post_save(self, action, created):
        if created:
            if action.share_instance:
                if action.action_type == constants.ACTION_TYPE_COMMENT:
                    action.share_instance.last_action_timestamp = action.added
                action.share_instance.cache_dirty = True
                action.share_instance.save()
                logger.debug("setting share instance %s cache_dirty to True" % (action.share_instance.id))
                popcaches.processInboxIds.delay([action.share_instance.id])
            elif (action.action_type == constants.ACTION_TYPE_PHOTOS_REQUESTED):
                notifications.sendRequestPhotosNotification.delay(action.id)
                

class RetrieveUpdateUserAPI(RetrieveUpdateAPIView):
    def get(self, request, id):
        maybeUserIdOrPhoneNum = id
        try:
            if maybeUserIdOrPhoneNum.startswith("+"):
                user = User.objects.get(phone_number=str(maybeUserIdOrPhoneNum))
            else:
                user = User.objects.get(id=maybeUserIdOrPhoneNum)
            serializer = LimitedUserSerializer(user)
            return Response(serializer.data)
        except:
            logger.warn("Had a request to get user by id %s and didn't find." % maybeUserIdOrPhoneNum)
            raise Http404

    # Putting this in to prevent invalid requests
    def put(self, request, id):
        if 'user_id' not in request.DATA or int(request.DATA['user_id']) != int(id) or int(request.DATA['user_id']) < 500:
            logger.warning("Rejecting request for user id %s due to invalid data" % id)
            raise Http404
        else:
            return super(RetrieveUpdateUserAPI, self).put(request, id)

    def pre_save(self, user):
        if 'build_id' in self.request.DATA and 'build_number' in self.request.DATA:
            # if last_build_info is empty or if either build_id or build_number is not in last_build_info
            #    update last_build_info
            buildId = self.request.DATA['build_id']
            buildNum = self.request.DATA['build_number']
            if ((not user.last_build_info) or 
                buildId not in user.last_build_info or 
                str(buildNum) not in user.last_build_info):
                user.last_build_info = "%s-%s" % (buildId, buildNum)
                logger.info("Build info updated to %s for user %s" % (user.last_build_info, user.id))


def updateStrandWithCorrectMetadata(strand, created):
    changed = False
    photos = strand.photos.all()
    for photo in photos:
        if photo.time_taken > strand.last_photo_time:
            strand.last_photo_time = photo.time_taken
            changed = True

        if photo.time_taken < strand.first_photo_time:
            strand.first_photo_time = photo.time_taken
            changed = True

    if len(photos) == 0 and created:
        if strand.created_from_id:
            createdFromStrand = Strand.objects.get(id=strand.created_from_id)
            strand.first_photo_time = createdFromStrand.first_photo_time
            strand.last_photo_time = createdFromStrand.last_photo_time
            strand.location_point = createdFromStrand.location_point
            strand.location_city = strands_util.getLocationForStrand(createdFromStrand)
            
            createNeighborRowsToNewStrand(strand, createdFromStrand)

            # This is used to mark the private strand that we've evaluated it and created a request/invite
            # from it
            createdFromStrand.suggestible = False
            createdFromStrand.save()

            changed = True
        else:
            logger.error("Tried to update a strand with 0 photos and not times set but didn't have created_from_id")
    return changed

# Add in strand Neighbor entries for all the private strands the created from one had
#  to the new public one
def createNeighborRowsToNewStrand(strand, privateStrand):
    newNeighbors = list()
    
    strandNeighbors = StrandNeighbor.objects.select_related().filter(Q(strand_1 = privateStrand) | Q(strand_2 = privateStrand))
    for strandNeighbor in strandNeighbors:
        if strandNeighbor.strand_2_id == privateStrand.id:
            # This means that the strand_1 in the neighbor is the one we want to use in the new Neighbor

            # The newly created strand will always have the higher id since it was just created
            newNeighbors.append(StrandNeighbor(strand_1=strandNeighbor.strand_1, strand_1_user=strandNeighbor.strand_1_user, strand_1_private=strandNeighbor.strand_1_private, strand_2=strand, strand_2_user=strand.user, strand_2_private=strand.private))
        else:
            # This means that strand_2 is the entry we want to copy...but it could be a strand neighbor or a user neighbor
            if strandNeighbor.strand_2:
                newNeighbors.append(StrandNeighbor(strand_1=strandNeighbor.strand_2, strand_1_user=strandNeighbor.strand_2_user, strand_1_private=strandNeighbor.strand_2_private, strand_2=strand, strand_2_user=strand.user, strand_2_private=strand.private))
            else:
                # This is a user neighbor so 
                newNeighbors.append(StrandNeighbor(strand_1=strand, strand_1_user=strand.user, strand_1_private=strand.private, strand_2_user=strandNeighbor.strand_2_user))

    if len(newNeighbors) > 0:
        strands_util.updateOrCreateStrandNeighbors(newNeighbors)
        logger.info("Wrote out or updated %s strand neighbor rows connecting neighbors of %s to new strand %s" % (len(newNeighbors), privateStrand.id, strand.id))


class CreateShareInstanceAPI(BulkCreateAPIView):
    lookup_field = 'id'
    serializer_class = BulkShareInstanceSerializer
    many_to_many_field = "users"

    # This is used right now by the bulk api so it can serialize each object
    # Could be refactored into parent if we use it more
    def sub_serializer(self, data):
        return ShareInstanceSerializer(data=data)

    def pre_save(self, shareInstance):
        now = datetime.datetime.utcnow()
        shareInstance.shared_at_timestamp = now
        shareInstance.last_action_timestamp = now

        # See if we've created something identical to this in the last few seconds
        timeCuttoff = datetime.datetime.utcnow() - datetime.timedelta(minutes=5)
        possibleMatches = ShareInstance.objects.prefetch_related('users').filter(user=shareInstance.user).filter(photo=shareInstance.photo).filter(added__gt=timeCuttoff)

        userIdsA = shareInstance.mtm_data

        for si in possibleMatches:
            userIdsB = ShareInstance.getIds(si.users.all())
            if userIdsA == userIdsB:
                shareInstance.do_not_create = True
                return

    def post_save(self, shareInstance, created):
        if created:
            action = Action.objects.create(user=shareInstance.user, photo_id=shareInstance.photo_id, share_instance=shareInstance, action_type=constants.ACTION_TYPE_PHOTO_EVALUATED)
            shareInstance.photo.owner_evaluated = True
            shareInstance.photo.save()

            popcaches.processInboxIds.delay([shareInstance.id])
            
class RetrieveUpdateDestroyShareInstanceAPIView(RetrieveUpdateDestroyAPIView):
    def pre_save(self, shareInstance):
        shareInstance.cache_dirty = True
        shareInstance.existingIds = set(User.getIds(shareInstance.users.all()))

    def post_save(self, shareInstance, created):
        popcaches.processInboxIds.delay([shareInstance.id])
        
        newIds =  [id for id in set(User.getIds(shareInstance.users.all())) if id not in shareInstance.existingIds]
       
        if shareInstance.photo.full_filename:
            for userId in newIds:
                notifications.sendNewPhotoNotificationBatch.delay(userId, [shareInstance.id])

    def delete(self, *args, **kwargs):
        shareInstance = None
        try:
            shareInstance = ShareInstance.objects.get(id=kwargs.get('id', None))
            userIds = User.getIds(shareInstance.users.all())
        except ShareInstance.DoesNotExist:
            pass

        ret = super(RetrieveUpdateDestroyShareInstanceAPIView, self).delete(*args, **kwargs)
        for userId in userIds:
            popcaches.processInboxFull.delay(userId)
    
        return ret


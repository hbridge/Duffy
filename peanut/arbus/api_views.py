import parsedatetime as pdt
import os, sys
import json
import subprocess
from PIL import Image
import time
import logging
import thread
import urllib2
import pprint
import datetime
import HTMLParser
import operator
import pytz
import uuid
from random import randint
from collections import Counter

from django.shortcuts import render
from django.template.loader import render_to_string
from django.http import HttpResponse
from django.core import serializers
from django.utils import timezone
from django.db.models import Count, Q
from django.db import IntegrityError
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.template import RequestContext, loader
from django.utils import timezone
from django.forms.models import model_to_dict
from django.http import Http404
from django.contrib.gis.geos import Point, fromstr

from haystack.query import SearchQuerySet

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response

from common.models import Photo, User, Similarity
from common.serializers import PhotoSerializer, UserSerializer
from common import api_util, cluster_util

from peanut.settings import constants

from arbus import image_util, search_util, location_util, suggestions_util
from arbus.forms import SearchQueryForm

import urllib
from dateutil.relativedelta import relativedelta

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

		if "bulk_photos" in request.DATA:
			photosData = json.loads(request.DATA["bulk_photos"])

			logger.info("Got request for bulk photo update with %s photos and %s files" % (len(photosData), len(request.FILES)))
			
			objsToCreate = list()
			objsToUpdate = list()

			batchKey = randint(1,10000)

			# fetch hashes for these photos to check for dups if this is a new install
			try:
				user = User.objects.get(id=photosData[0]['user'])
			except User.DoesNotExist:
				return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")
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
			for photoData in photosData:
				photoData = self.jsonDictToSimple(photoData)
				photoData["bulk_batch_key"] = batchKey

				photo = self.simplePhotoSerializer(photoData)

				self.populateExtraData(photo)

				#if photo.iphone_hash in existingPhotosByHash:
				#	existingPhoto = existingPhotosByHash[photo.iphone_hash]
				#	existingPhoto.file_key = photo.file_key

				#	objsToUpdate.append(existingPhoto)
				if photo.id:
					objsToUpdate.append(photo)
				else:
					objsToCreate.append(photo)
				
			self.populateTimezonesForPhotos(objsToCreate)
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
"""
	Autocomplete which takes in user_id and q and returns back matches and counts
"""
@csrf_exempt
def autocomplete(request):
	startTime = time.time()
	data = api_util.getRequestData(request)
	htmlParser = HTMLParser.HTMLParser()
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return api_util.returnFailure(response, "Need user_id")

	if data.has_key('q'):
		query = htmlParser.unescape(data['q'])
	else:
		return api_util.returnFailure(response, "Need q")

	# For now, we're going to search for only the first word, and we'll filter later
	firstWord = query.split(" ")[0]
	sqs = SearchQuerySet().autocomplete(content_auto=firstWord).filter(userId=userId)[:1000]

	# Create a list of suggestions, which are the phrases the user will see
	suggestions = list()
	for photo in sqs:
		phrases = photo.content_auto.split('\n')
		for phrase in phrases:
			suggestions.extend([a.strip() for a in phrase.split(',')])

	# This turns our list of suggestions into a dict of suggestion : count
	suggestionCounts = Counter(suggestions)
	resultSuggestions = dict()

	for suggestionPhrase in suggestionCounts:
		# We'll search based on lower case but maintain case for the results
		lowerPhrase = suggestionPhrase.lower()
		if len(query.split(" ")) > 1:
			# If we have a space in the query then we're going to do substring
			if lowerPhrase.find(query) >= 0:
				resultSuggestions[suggestionPhrase] = suggestionCounts[suggestionPhrase]
		else:
			# there's no space, then we'll break apart the words and do a startswith
			for suggestionWord in lowerPhrase.split(" "):
				if suggestionWord.startswith(query):
					resultSuggestions[suggestionPhrase] = suggestionCounts[suggestionPhrase]

	sortedSuggestions = sorted(resultSuggestions.iteritems(), key=operator.itemgetter(1), reverse=True)

	# Reformat into a list so we can hand back 
	results = list()
	order = 0
	for suggestion in sortedSuggestions:
		phrase, count = suggestion
		countPhrase = getCountPhrase(count)
		entry = {'name': phrase, 'count': count, 'count_phrase': countPhrase, 'order': order}
		order += 1
		results.append(entry)

	if ('settings'.startswith(query.lower())):
		entry = {'name': 'settings', 'count': 1, 'count_phrase': 1, 'order': order}
		results.append(entry)

	# Make sure you return a JSON object, not a bare list.
	# Otherwise, you could be vulnerable to an XSS attack.
	responseJson = json.dumps({
		'results': results,
		'query_time': (time.time() - startTime),
	})

	
	return HttpResponse(responseJson, content_type='application/json')

"""
Search API

Takes in a query, number of entries to fetch, and a startDate (all fields in forms.py SearchQueryForm)

"""
@csrf_exempt
def search(request):
	response = dict()

	form = SearchQueryForm(request.GET) # A form bound to the POST data
	if form.is_valid(): # All validation rules pass
		query = form.cleaned_data['q']
		user_id = form.cleaned_data['user_id']
		startDateTime = form.cleaned_data['start_date_time']
		num = form.cleaned_data['num']
		# Reversed
		r = form.cleaned_data['r']
		docstack = form.cleaned_data['docstack']
		
		# See if out query has a time associated within it
		(nattyStartDate, newQuery) = search_util.getNattyInfo(query)

		if not startDateTime:
			if (nattyStartDate):
				startDateTime = nattyStartDate
			else:
				startDateTime = datetime.date(1901,1,1)
		
		# Get a search for 2 times the number of entries we want to return, we will filter it down loater
		if (query == "''" and docstack):
			searchResults = search_util.solrSearch(user_id, startDateTime, newQuery, reverse = r, limit=num*2, exclude='docs screenshot')
			docResults = search_util.solrSearch(user_id, startDateTime, 'docs screenshot', reverse = r, limit=num, operator='OR')
		else:
			searchResults = search_util.solrSearch(user_id, startDateTime, newQuery, reverse = r, limit = num*2)
			docResults = None

		if (len(searchResults) > 0 or docResults and len(docResults) > 0):	
			# Group into months
			monthGroupings = cluster_util.splitPhotosFromIndexbyMonth(user_id, searchResults, docResults=docResults)

			# Grap the objects to turn into json, called sections.  Also limit by num and get the lastDate
			#   which is the key for the next call
			sections = api_util.turnFormattedGroupsIntoSections(monthGroupings, num)

			response['objects'] = sections
		else:
			response['retry_suggestions'] = suggestions_util.getTopCombos(user_id)
		response['result'] = True
		return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

	else:
		response['result'] = False
		response['errors'] = json.dumps(form.errors)
		return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")


"""
	Fetches all photos for the given user and returns back two things:
	1) the all cities with their counts.  Results are unsorted.
	2) top suggestions for categories with counts.
	
	Returns JSON of the format:
	{"top_locations": [
		{"San Francisco": 415},
		{"New York": 246},
		{"Barcelona": 900},
		{"Montepulciano": 47},
		{"New Delhi": 39}
		],
		"top_categories": [
		{"food": 415},
		{"animal": 300},
		{"car": 240}
		],
		"top_timestamps": [
		{"last week": 415},
		{"last summer": 300},
		{"mar 2014": 240}
		]
	}
"""
@csrf_exempt
def get_suggestions(request):
	response = dict({'result': True})

	data = api_util.getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return api_util.returnFailure(response, "Need user_id")

	if data.has_key('limit'):
		limit = int(data['limit'])
	else:
		limit = 10

	response['top_locations'] = suggestions_util.getTopLocations(userId, limit)
	response['top_categories'] = suggestions_util.getTopCategories(userId, limit)
	response['top_times'] = suggestions_util.getTopTimes(userId)
	
	return HttpResponse(json.dumps(response), content_type="application/json")



"""
	Small method to get a user's info based on their id
	Can be passed in either user_id or phone_id
	Returns the JSON equlivant of the user
"""
@csrf_exempt
def get_user(request, productId = 0):
	response = dict({'result': True})
	user = None
	data = api_util.getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
		user = User.objects.get(id=userId)
	
	if data.has_key('phone_id'):
		phoneId = data['phone_id']
		try:
			user = User.objects.get(Q(phone_id=phoneId) & Q(product_id=productId))
		except User.DoesNotExist:
			logger.error("Could not find user: %s %s" % (phoneId, productId))
			return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

	#if user is None:
	#	return returnFailure(response, "User not found.  Need valid user_id or phone_id")

	if (user):
		serializer = UserSerializer(user)
		response['user'] = serializer.data
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

"""
	Creates a new user, if it doesn't exist
"""

@csrf_exempt
def create_user(request, productId = 0):
	response = dict({'result': True})
	user = None
	data = api_util.getRequestData(request)

	if data.has_key('device_name'):
		firstName =  data['device_name']
	else:
		firstName = ""

	if data.has_key('phone_id'):
		phoneId = data['phone_id']
		try:
			user = User.objects.get(Q(phone_id=phoneId) & Q(product_id=productId))
			return api_util.returnFailure(response, "User already exists")
		except User.DoesNotExist:
			user = createUser(phoneId, firstName, productId)
	else:
		return api_util.returnFailure(response, "Need a phone_id")

	serializer = UserSerializer(user)
	response['user'] = serializer.data
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

"""
Helper functions
"""
	
"""
	Utility method to create a user in the database and create all needed file top_locations
	for the image pipeline

	This could be located else where
"""
def createUser(phoneId, firstName, productId):
	user = User(display_name = firstName, phone_id = phoneId, product_id = productId)
	user.save()

	userBasePath = user.getUserDataPath()

	try:
		os.stat(userBasePath)
	except:
		os.mkdir(userBasePath)
		os.chmod(userBasePath, 0775)

	return user

def getCountPhrase(count):
	if count == 0:
		return ""
	elif count == 1:
		return "1"
	elif count < 5:
		return "2+"
	elif count < 10:
		return "5+"
	elif count < 50:
		return "20+"
	elif count < 150:
		return "50+"
	else:
		return "100+"

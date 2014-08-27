import parsedatetime as pdt
import os, sys
import json
import subprocess
from PIL import Image
import time
import logging
import thread
import pprint
import datetime
import HTMLParser
import operator
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

from common.models import Photo, User, Neighbor, Similarity
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
		if not photo.time_taken:
			photo.time_taken = image_util.getTimeTakenFromExtraData(photo, True)
			logger.debug("Didn't find time_taken, looked myself and found %s" % (photo.time_taken))

		# Bug fix for bad data in photo where date was before 1900
		# Initial bug was from a photo in iPhone 1, guessing at the date
		if (photo.time_taken.date() < datetime.date(1900, 1, 1)):
			logger.warning("Found a photo with a date earlier than 1900: %s" % (photo.id))
			photo.time_taken = datetime.date(2007, 9, 1)

		lat, lon, accuracy = location_util.getLatLonAccuracyFromExtraData(photo, True)

		if not photo.location_point and (lat and lon):
			photo.location_point = fromstr("POINT(%s %s)" % (lon, lat))
			photo.location_accuracy_meters = accuracy

			logger.debug("For photo %s, Looked for lat lon and got %s" % (photo.id, photo.location_point))
			logger.debug("With accuracy %s" % (photo.location_accuracy_meters))
		elif accuracy and accuracy < photo.location_accuracy_meters:
			logger.debug("For photo %s, Updated location from %s  to  %s " % (photo.id, photo.location_point, fromstr("POINT(%s %s)" % (lon, lat))))
			logger.debug("And accuracy from %s to %s", photo.location_accuracy_meters, accuracy)

			photo.location_point = fromstr("POINT(%s %s)" % (lon, lat))
			photo.location_accuracy_meters = accuracy

			if photo.strand_evaluated:
				photo.strand_needs_reeval = True
		elif accuracy and accuracy >= photo.location_accuracy_meters:
			logger.debug("For photo %s, Got new accuracy but was the same or greater:  %s  %s" % (photo.id, accuracy, photo.location_accuracy_meters))
	
		return photo

	def populateExtraDataForPhotos(self, photos):
		for photo in photos:
			self.populateExtraData(photo)
		return photos

	def simplePhotoSerializer(self, photoDict):
		photoDict["user_id"] = photoDict["user"]
		del photoDict["user"]

		photo = Photo(**photoDict)

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
				photos = self.populateExtraData(serializer.object)
				Photo.bulkUpdate(photo, ["location_point", "strand_needs_reeval", "location_accuracy_meters", "full_filename", "thumb_filename", "metadata", "time_taken"])
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
	"""
		This goes through and tries to save each photo and deals with IntegrityError's (dups)
		If we find one, grab the current one in the db (which could be wrong), and update it
		with the latest info
	"""
	def handleDups(self, photos, dupPhotoData):
		photoDups = list()
		for i, photo in enumerate(photos):
			try:
				photo.save()
			except IntegrityError:
				dup = Photo.objects.filter(iphone_hash=photo.iphone_hash).filter(user=photo.user)
				if len(dup) > 0:
					logger.warning("Found dup photo in upload: " + str(dup[0].id))
					serializer = PhotoSerializer(dup[0], data=dupPhotoData[i], partial=True)
					if serializer.is_valid():
						serializer.save()
						photoDups.append(serializer.object)

				if len(dup) > 1:
					logger.error("Validation error for user id: " + str(photo.user) + " and " + photo.iphone_hash)
		return photoDups


	def post(self, request, format=None):
		response = list()

		startTime = datetime.datetime.now()

		if "bulk_photos" in request.DATA:
			logger.info("Got request for bulk photo update with %s files" % len(request.FILES))
			photosData = json.loads(request.DATA["bulk_photos"])

			objsToCreate = list()

			# Keep this around incase we find dups, then we can update the photo with new data
			dupPhotoData = list()
			batchKey = randint(1,10000)

			for photoData in photosData:
				photoData = self.jsonDictToSimple(photoData)
				photoData["bulk_batch_key"] = batchKey
				
				photo = self.simplePhotoSerializer(photoData)

				self.populateExtraData(photo)
				objsToCreate.append(photo)

				dupPhotoData.append(photoData)

			# Dups happen when the iphone doesn't think its uploaded a photo, but we have seen it before
			#   (maybe connection died).  So if we can't create in bulk, do it individually and track which
			#   ones were created
			dups = list()
			try:
				Photo.objects.bulk_create(objsToCreate)
			except IntegrityError:
				logger.warning("Found dups in bulk upload")
				dups = self.handleDups(objsToCreate, dupPhotoData)

			# Only want to grab stuff from the last 60 seconds since bulk_batch_key could repeat
			dt = datetime.datetime.now() - datetime.timedelta(seconds=60)

			# This grabs all photos created in bulk_create and dups, since we're updating the batch_key
			# with dups
			createdPhotos = list(Photo.objects.filter(bulk_batch_key = batchKey).filter(updated__gt=dt))

			# Now that we've created the images in the db, we need to deal with any uploaded images
			#   and fill in any EXIF data (time_taken, gps, etc)
			if len(createdPhotos) > 0:
				logger.debug("Successfully created %s entries in db, now processing photos" % (len(createdPhotos)))

				# This will move the uploaded image over to the filesystem, and create needed thumbs
				numImagesProcessed = image_util.handleUploadedImagesBulk(request, createdPhotos)

				if numImagesProcessed > 0:
					# These are all the fields that we might want to update.  List of the extra fields from above
					# TODO(Derek):  Probably should do this more intelligently
					Photo.bulkUpdate(createdPhotos, ["full_filename", "thumb_filename"])
			else:
				logger.error("For some reason got back 0 photos created.  Using batch key %s at time %s", batchKey, dt)
			
			for photo in createdPhotos:
				response.append(model_to_dict(photo))

			# We don't need to update/save the dups since other code does that, but we still
			#   want to add it to the response
			for photo in dups:
				response.append(model_to_dict(photo))

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
			lastDate, sections = api_util.turnGroupsIntoSections(monthGroupings, num)

			response['objects'] = sections
			response['next_start_date_time'] = datetime.datetime.strftime(lastDate, '%Y-%m-%d %H:%M:%S')
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
			return HttpResponse(json.dumps(response), content_type="application/json")

	#if user is None:
	#	return returnFailure(response, "User not found.  Need valid user_id or phone_id")

	if (user):
		serializer = UserSerializer(user)
		response['user'] = serializer.data
	return HttpResponse(json.dumps(response), content_type="application/json")

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
	return HttpResponse(json.dumps(response), content_type="application/json")

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

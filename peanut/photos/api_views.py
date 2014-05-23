import parsedatetime as pdt
import os, sys
import json
import subprocess
import Image
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
from django.db.models import Count
from django.db import IntegrityError
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.template import RequestContext, loader
from django.utils import timezone
from django.forms.models import model_to_dict
from django.http import Http404

from haystack.query import SearchQuerySet

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response

from photos.models import Photo, User, Classification
from photos import image_util, search_util, gallery_util, location_util, cluster_util, suggestions_util
from photos.serializers import PhotoSerializer
from .forms import ManualAddPhoto

import urllib
from dateutil.relativedelta import relativedelta

logger = logging.getLogger(__name__)

class PhotoAPI(APIView):
	# TODO(derek)  pull this out to shared class
	def jsonDictToSimple(self, jsonDict):
		ret = dict()
		for key in jsonDict:
			var = jsonDict[key]
			if type(var) is dict or type(var) is list:
				ret[key] = json.dumps(jsonDict[key])
			else:
				ret[key] = str(var)

		return ret
		
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

		serializer = PhotoSerializer(photo, data=photoData)
		if serializer.is_valid():
			serializer.save()

			image_util.handleUploadedImage(request, serializer.data["file_key"], serializer.object)
			return Response(serializer.data)
		else:
			logger.info("Photo serialization failed, returning 400.  Errors %s" % (serializer.errors))
			return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
		return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

	def post(self, request, format=None):
		serializer = PhotoSerializer(data=request.DATA)
		if serializer.is_valid():
			try:
				serializer.save()
				image_util.handleUploadedImage(request, serializer.data["file_key"], serializer.object)
			except IntegrityError:
				logger.error("IntegrityError")
				Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
				
			return Response(serializer.data, status=status.HTTP_201_CREATED)
		return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class PhotoBulkAPI(APIView):
	# TODO(derek)  pull this out to shared class
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
					serializer = PhotoSerializer(dup[0], data=dupPhotoData[i])
					if serializer.is_valid():
						serializer.save()
						photoDups.append(serializer.object)

				if len(dup) > 1:
					logger.error("Validation error for user id: " + str(photo.user) + " and " + photo.iphone_hash)
		return photoDups

	def post(self, request, format=None):
		response = list()
		
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
				serializer = PhotoSerializer(data=photoData)
				if serializer.is_valid():
					objsToCreate.append(serializer.object)
					dupPhotoData.append(photoData)
				else:
					logger.error("Photo serialization failed, returning 400.  Errors %s" % (serializer.errors))
					return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
			
			dups = list()
			try:
				Photo.objects.bulk_create(objsToCreate)
			except IntegrityError:
				logger.warning("Found dups in bulk upload")
				dups = self.handleDups(objsToCreate, dupPhotoData)

			# Only want to grab stuff from the last 60 seconds since bulk_batch_key could repeat
			dt = datetime.datetime.utcnow() - datetime.timedelta(seconds=60)

			# This grabs all photos created in bulk_create and dups, since we're updating the batch_key
			# with dups
			createdPhotos = Photo.objects.filter(bulk_batch_key = batchKey).filter(updated__gt=dt)

			updatedPhotos = list()
			if len(createdPhotos) > 0:
				updatedPhotos = image_util.handleUploadedImagesBulk(request, createdPhotos)

			for photo in updatedPhotos:
				serializer = PhotoSerializer(photo)
				response.append(serializer.data)

			for photo in dups:
				serializer = PhotoSerializer(photo)
				response.append(serializer.data)

			return Response(response, status=status.HTTP_201_CREATED)
		else:
			logger.error("Got request with no bulk_photos, returning 400")
			return Response(response, status=status.HTTP_400_BAD_REQUEST)

"""
	Temporary start to autocomplete
"""
@csrf_exempt
def autocomplete(request):
	startTime = time.time()
	data = getRequestData(request)
	htmlParser = HTMLParser.HTMLParser()
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return returnFailure(response, "Need user_id")

	if data.has_key('q'):
		query = htmlParser.unescape(data['q'])
	else:
		return returnFailure(response, "Need q")

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
		entry = {'phrase': phrase, 'count': count, 'order': order}
		order += 1
		results.append(entry)

	# Make sure you return a JSON object, not a bare list.
	# Otherwise, you could be vulnerable to an XSS attack.
	responseJson = json.dumps({
		'results': results,
		'query_time': (time.time() - startTime),
	})

	
	return HttpResponse(responseJson, content_type='application/json')

"""
Search api function that returns the search view. Used by the /viz/search?user_id=<userID>
"""
@csrf_exempt
def search(request):
	data = getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return returnFailure(response, "Need user_id")

	if data.has_key('imagesize'):
		query = data['imagesize']
	else:
		imageSize = 78

	width = imageSize*2 #doubled  for retina

	if data.has_key('page'):
		page = int(data['page'])
	else:
		page = 1

	if data.has_key('q'):
		query = data['q']
	else:
		query = ''

	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		return returnFailure(response, "Invalid user_id")

	
	thumbnailBasepath = "/user_data/" + userId + "/"

	response = ''

	allResults = SearchQuerySet().all().filter(userId=userId).order_by('timeTaken')

	(startDate, newQuery) = search_util.getNattyInfo(query)

	if (allResults.count() > 0):
		if (startDate == None):
			startDate = allResults[0].timeTaken
		(pageStartDate, pageEndDate) = search_util.pageToDates(page, startDate)
		searchResults = search_util.solrSearch(user.id, pageStartDate, newQuery, pageEndDate)
		while (searchResults.count() < 10 and pageEndDate < datetime.datetime.utcnow()):
			pageEndDate = pageEndDate+relativedelta(months=3)
			page +=1
			searchResults = search_util.solrSearch(user.id, pageStartDate, newQuery, pageEndDate)
		photoResults = gallery_util.splitPhotosFromIndexbyMonth(user.id, searchResults, startDate=pageStartDate, endDate=pageEndDate)

		for entry in photoResults:
			context = {	'imageSize': imageSize,
						'userId': userId,
						'entry': entry,
						'thumbnailBasepath': thumbnailBasepath}

			html = render_to_string('photos/_timeline_block.html', context)
			response += html
	
		if (pageEndDate < datetime.datetime.utcnow()):
			nextLink = '<a class="jscroll-next" href="/api/search?user_id=' + str(userId) + '&q=' + urllib.quote(query) + '&page=' + str(page+1) +'">Next</a>'
			response += nextLink
	return HttpResponse(response, content_type="application/html")


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

	data = getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return returnFailure(response, "Need user_id")

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
def get_user(request):
	response = dict({'result': True})
	user = None
	data = getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
		user = User.objects.get(id=userId)
	
	if data.has_key('phone_id'):
		phoneId = data['phone_id']
		try:
			user = User.objects.get(phone_id=phoneId)
		except User.DoesNotExist:
			return HttpResponse(json.dumps(response), content_type="application/json")

	#if user is None:
	#	return returnFailure(response, "User not found.  Need valid user_id or phone_id")

	if (user):
		response['user'] = model_to_dict(user)
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Creates a new user, if it doesn't exist
"""

@csrf_exempt
def create_user(request):
	response = dict({'result': True})
	user = None
	data = getRequestData(request)

	if data.has_key('device_name'):
		firstName =  data['device_name']
	else:
		firstName = ""

	if data.has_key('phone_id'):
		phoneId = data['phone_id']
		try:
			user = User.objects.get(phone_id=phoneId)
			return returnFailure(response, "User already exists")
		except User.DoesNotExist:
			user = createUser(phoneId, firstName)
	else:
		return returnFailure(response, "Need a phone_id")

	response['user'] = model_to_dict(user)
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
Helper functions
"""
def getRequestData(request):
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	return data
	
def returnFailure(response, msg):
	response['result'] = False
	response['debug'] = msg
	return HttpResponse(json.dumps(response), content_type="application/json")

	
"""
	Utility method to create a user in the database and create all needed file top_locations
	for the image pipeline

	This could be located else where
"""
def createUser(phoneId, firstName):
	uploadsPath = "/home/derek/pipeline/uploads"
	basePath = "/home/derek/user_data"
	remoteHost = 'duffy@titanblack.no-ip.biz'
	remoteStagingPath = '/home/duffy/pipeline/staging'

	user = User(first_name = firstName, last_name = "", phone_id = phoneId)
	user.save()

	userId = str(user.id)
	userUploadsPath = os.path.join(uploadsPath, userId)
	userBasePath = os.path.join(basePath, userId)

	try:
		os.stat(userBasePath)
	except:
		os.mkdir(userBasePath)
		os.chmod(userBasePath, 0775)

	userRemoteStagingPath = os.path.join(remoteStagingPath, userId)
	subprocess.call(['ssh', remoteHost, "mkdir -p " + userRemoteStagingPath])

	return user


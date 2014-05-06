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
from random import randint

from django.shortcuts import render
from django.template.loader import render_to_string
from django.http import HttpResponse
from django.core import serializers
from django.utils import timezone
from django.db.models import Count
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.template import RequestContext, loader
from django.utils import timezone
from django.forms.models import model_to_dict
from django.http import Http404

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response

from photos.models import Photo, User, Classification
from photos import image_util, search_util, gallery_util, location_util, cluster_util
from photos.serializers import PhotoSerializer
from .forms import ManualAddPhoto

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
			raise Http404

	def get(self, request, photoId, format=None):
		photo = self.getObject(photoId)
		serializer = PhotoSerializer(photo)
		return Response(serializer.data)

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

			# TODO(derek): get these working again, leaving as place holder
			#thread.start_new_thread(Photo.populateExtraData, (serializer.data["id"],))
			#thread.start_new_thread(cluster_util.startThreadCluster, (serializer.data["id"],))

			return Response(serializer.data)
		else:
			print "Serializer errors"
			logger.error(serializer.errors)
		return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

	def post(self, request, format=None):
		serializer = PhotoSerializer(data=request.DATA)
		if serializer.is_valid():
			serializer.save()

			image_util.handleUploadedImage(request, serializer.data["file_key"], serializer.object)
			
			thread.start_new_thread(Photo.populateExtraData, (serializer.data["id"],))
			thread.start_new_thread(cluster_util.startThreadCluster, (serializer.data["id"],))

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

	def post(self, request, format=None):
		response = list()
		
		if "bulk_photos" in request.DATA:
			photosData = json.loads(request.DATA["bulk_photos"])

			objsToCreate = list()
			batchKey = randint(1,10000)

			for photoData in photosData:
				photoData = self.jsonDictToSimple(photoData)
				photoData["bulk_batch_key"] = batchKey
				serializer = PhotoSerializer(data=photoData)
				if serializer.is_valid():
					objsToCreate.append(serializer.object)

					# TODO(derek): get these working again, leaving as place holder
					#thread.start_new_thread(Photo.populateExtraData, (serializer.data["id"],))
					#thread.start_new_thread(cluster_util.startThreadCluster, (serializer.data["id"],))
				else:
					return Response(response, status=status.HTTP_400_BAD_REQUEST)
					
			Photo.objects.bulk_create(objsToCreate)

			# Only want to grab stuff from the last 60 seconds since bulk_batch_key could repeat
			dt = datetime.datetime.utcnow() - datetime.timedelta(seconds=60)
			createdPhotos = Photo.objects.filter(bulk_batch_key = batchKey).filter(updated__gt=dt)

			updatedPhotos = image_util.handleUploadedImagesBulk(request, createdPhotos)
			
			for photo in updatedPhotos:
				serializer = PhotoSerializer(photo)
				response.append(serializer.data)

			return Response(response, status=status.HTTP_201_CREATED)
		return Response(response, status=status.HTTP_400_BAD_REQUEST)

"""
	Add a photo that is submitted through a POST.  Both the manualAddPhoto webpage
	and the iPhone app call this endpoint.

	This creates a database entry for the photo and copies it into the user directory
"""
@csrf_exempt
def add_photo(request):
	response_data = {}

	if request.method == 'POST':
		form = ManualAddPhoto(request.POST, request.FILES)
		if form.is_valid():
			phoneId = form.cleaned_data['phone_id']
			photoMetadata = form.cleaned_data['photo_metadata']
			locationData = form.cleaned_data['location_data']
			iPhoneFaceboxesTopleft = form.cleaned_data['iphone_faceboxes_topleft']

			try:
				user = User.objects.get(phone_id=phoneId)
			except User.DoesNotExist:
				user = createUser(phoneId, "")

			tempFilepath = tempfile.mktemp()
 
			image_util.writeOutUploadedFile(request.FILES['file'], tempFilepath)
			image_util.addPhoto(user, request.FILES['file'].name, tempFilepath, photoMetadata, locationData, iPhoneFaceboxesTopleft)

			response_data['result'] = True
			response_data['debug'] = ""
			return HttpResponse(json.dumps(response_data), content_type="application/json")
		else:
			response_data['result'] = False
			response_data['debug'] = 'Form data is incorrect'
			return HttpResponse(json.dumps(response_data), content_type="application/json")
	else:
		return HttpResponse("This needs to be a POST")



"""
Search api function that returns the gallery view. Used by the /viz/search?user_id=<userID>
"""
@csrf_exempt
def search(request):
	response = dict({'result': True})

	data = getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return returnFailure(response, "Need user_id")

	if data.has_key('q'):
		query = data['q']
	else:
		return returnFailure(response, "Need q field")

	if data.has_key('imagesize'):
		query = data['imagesize']
	else:
		imageSize = 78

	width = imageSize*2 #doubled  for retina

	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		return returnFailure(response, "Invalid user_id")

	(startDate, newQuery) = search_util.getNattyInfo(query)
	searchResults = search_util.solrSearch(userId, startDate, newQuery)
	
	thumbnailBasepath = "/user_data/" + userId + "/"

	response['_timeline_block_html'] = list()

	#allResults = searchResults.count()
	photoResults = gallery_util.splitPhotosFromIndexbyMonth(userId, searchResults)

	photoIdToThumb = dict()
	resultsDict = dict()
	for result in searchResults:
		photoIdToThumb[result.photoId] = image_util.imageThumbnail(result.photoFilename, width, userId)
	
	resultsDict['photoIdToThumb'] = photoIdToThumb

	for entry in photoResults:
		context = {	'imageSize': imageSize,
					'resultsDict': resultsDict,
					'userId': userId,
					'entry': entry,
					'thumbnailBasepath': thumbnailBasepath}

		html = render_to_string('photos/_timeline_block.html', context)
		response['_timeline_block_html'].append(html)

	return HttpResponse(json.dumps(response), content_type="application/json")


"""
Old search api function, used by ajax call from /viz/search/<user_id>
"""
@csrf_exempt
def searchJQmobile(request):
	response = dict({'result': True})

	data = getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return returnFailure(response, "Need user_id")

	if data.has_key('q'):
		query = data['q']
	else:
		return returnFailure(response, "Need q field")

	(startDate, newQuery) = search_util.getNattyInfo(query)
	searchResults = search_util.solrSearch(userId, startDate, newQuery)
	
	thumbnailBasepath = "/user_data/" + userId + "/"

	response['search_result_html'] = list()

	if startDate:
		response['search_result_html'].append("Using date: " + str(startDate))
			
	for result in searchResults:
		context = {	'userId': userId,
					'photoFilename': result.photoFilename,
					'thumbnailBasepath': thumbnailBasepath,
					'photoId': result.photoId,
					'result': result}
		if result.locationData:
			context['locationData'] = json.loads(result.locationData)
		if result.classificationData:
			context['classificationData'] = json.loads(result.classificationData)
		

		html = render_to_string('photos/search_result.html', context)
		response['search_result_html'].append(html)

	return HttpResponse(json.dumps(response), content_type="application/json")


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

	response['top_locations'] = getTopLocations(userId)
	response['top_categories'] = getTopCategories(userId)
	response['top_times'] = getTopTimes(userId)
	
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

"""
	Fetches all photos for the given user and returns back the all cities with their counts.  Results are
	unsorted.

	[{"San Francisco": 415},
		{"New York": 246},
		{"Barcelona": 900},
		{"Montepulciano": 47},
		{"New Delhi": 39}]
"""
def getTopLocations(userId):

	queryResult = Photo.objects.filter(user_id=userId).values('location_city').order_by().annotate(Count('location_city')).order_by('-location_city__count')
	
	photoLocations = list()
	for location in queryResult:
		entry = dict()
		entry['name'] = location['location_city']
		entry['count'] = location['location_city__count']
		photoLocations.append(entry)
	
	return photoLocations

"""
	Fetches all photos for the given user and returns back top categories with count. Currently, faking it.

	[{"food": 415},
		{"animal": 246},
		{"car": 90}]
"""
def getTopCategories(userId):

	return [{'name': 'people', 'count': 8},
			{'name': 'food', 'count': 8}, 
			{'name': 'screenshots', 'count': 6}, 
			{'name': 'animal', 'count': 4}, 
			{'name': 'car', 'count': 2}]



"""
	Fetches all photos for the given user and returns back top time searches with count. Currently, faking it.

	[{"last week": 415},
		{"feb 2014": 246},
		{"last summer": 90}]
"""
def getTopTimes(userId):

	return [{'name': 'last week', 'count': 3}, {'name': 'feb 2014', 'count': 2}, {'name': 'last summer', 'count': 1}]



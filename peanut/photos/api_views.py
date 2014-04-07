import parsedatetime as pdt
import os, sys
import json
import subprocess
import Image

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

from photos.models import Photo, User, Classification
from photos import image_util, search_util
from .forms import ManualAddPhoto

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
				user = createUser(phoneId)

			image_util.addPhoto(user, request.FILES['file'].name, request.FILES['file'], photoMetadata, locationData, iPhoneFaceboxesTopleft)

			response_data['result'] = True
			response_data['debug'] = ""
			return HttpResponse(json.dumps(response_data), content_type="application/json")
		else:
			response_data['result'] = False
			response_data['debug'] = 'Form data is incorrect'
			return HttpResponse(json.dumps(response_data), content_type="application/json")
	else:
		return HttpResponse("This needs to be a POST")


@csrf_exempt
def search(request):
	response = dict({'result': True})

	data = getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return returnFailure(response, "Need user_id")

	if data.has_key('user_id'):
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
	Fetches all photos for the given user and returns back the all cities with their counts.  Results are
	unsorted.
	
	Returns JSON of the format:
	{"top_locations": [
		{"San Francisco": 415},
		{"New York": 246},
		{"Barcelona": 900},
		{"Montepulciano": 47},
		{"New Delhi": 39}
		]
	}
"""
@csrf_exempt
def get_top_locations(request):
	response = dict({'result': True})

	data = getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return returnFailure(response, "Need user_id")
		
	queryResult = Photo.objects.filter(user_id=userId).values('location_city').order_by().annotate(Count('location_city')).order_by('-location_city__count')
	
	photoLocations = list()
	for location in queryResult:
		entry = dict()
		entry['name'] = location['location_city']
		entry['count'] = location['location_city__count']
		photoLocations.append(entry)
		
	response['top_locations'] = photoLocations
	
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
		user = User.objects.get(phone_id=phoneId)

	if user is None:
		return returnFailure(response, "User not found.  Need valid user_id or phone_id")

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
def createUser(phoneId):
	uploadsPath = "/home/derek/pipeline/uploads"
	basePath = "/home/derek/user_data"
	remoteHost = 'duffy@titanblack.no-ip.biz'
	remoteStagingPath = '/home/duffy/pipeline/staging'

	user = User(first_name="", last_name="", phone_id = phoneId)
	user.save()

	userId = str(user.id)
	userUploadsPath = os.path.join(uploadsPath, userId)
	userBasePath = os.path.join(basePath, userId)

	try:
		os.stat(userUploadsPath)
	except:
		os.mkdir(userUploadsPath)

	try:
		os.stat(userBasePath)
	except:
		os.mkdir(userBasePath)

	userRemoteStagingPath = os.path.join(remoteStagingPath, userId)
	subprocess.call(['ssh', remoteHost, "mkdir -p " + userRemoteStagingPath])

	return user

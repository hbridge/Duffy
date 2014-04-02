from django.shortcuts import render
from django.template.loader import render_to_string
from django.http import HttpResponse
from django.core import serializers
from .forms import ManualAddPhoto
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt, csrf_protect

from haystack.query import SearchQuerySet
from haystack.inputs import Raw

from django.template import RequestContext, loader
import parsedatetime as pdt
import urllib2
import urllib

import os
from time import mktime
from datetime import datetime
import json
import subprocess

from photos.models import Photo, User, Classification

def handle_uploaded_file(user, uploadedFile, newFilePath):
	print("Writing to " + newFilePath)

	with open(newFilePath, 'wb+') as destination:
		for chunk in uploadedFile.chunks():
			destination.write(chunk)

def manualAddPhoto(request):
	form = ManualAddPhoto()

	context = {'form' : form}
	return render(request, 'photos/manualAddPhoto.html', context)

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


@csrf_exempt
def addPhoto(request):
	uploadsPath = "/home/derek/pipeline/uploads"
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

			photo = Photo(	user = user,
							location_data = locationData,
							orig_filename = request.FILES['file'].name,
							upload_date = timezone.now(),
							metadata = photoMetadata,
							iphone_faceboxes_topleft = iPhoneFaceboxesTopleft)
			photo.save()

			filename, fileExtension = os.path.splitext(request.FILES['file'].name)
			newFilename = str(photo.id) + fileExtension

			userUploadsPath = os.path.join(uploadsPath, str(user.id))
			newFilePath = os.path.join(userUploadsPath, newFilename)

			photo.new_filename = newFilename
			photo.save()

			handle_uploaded_file(user, request.FILES['file'], newFilePath)

			response_data['result'] = True
			response_data['filename'] = newFilePath
			response_data['debug'] = photoMetadata
			return HttpResponse(json.dumps(response_data), content_type="application/json")
		else:
			response_data['result'] = False
			response_data['debug'] = 'Form data is incorrect'
			return HttpResponse(json.dumps(response_data), content_type="application/json")
	else:
		return HttpResponse("This needs to be a POST")

@csrf_exempt
def search(request):
	response = dict()
	response['result'] = True
	startDate = ""
	endDate = ""
	queryStartDate = ""

	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		response['result'] = False
		response['debug'] = "need user_id"
		return HttpResponse(json.dumps(response), content_type="application/json")

	if data.has_key('q'):
		query = data['q']
	else:
		response['result'] = False
		response['debug'] = "need query"
		return HttpResponse(json.dumps(response), content_type="application/json")

	"""
	Old javascript date parsing code - probably ca
	if data.has_key('startDate'):
		if data['startDate']:
			queryStartDate = int(data['startDate'])
			print queryStartDate
			dt = datetime.fromtimestamp(queryStartDate)

			response['dateInfo'] = str(dt)
			response['startDate'] = str(startDate)

			#timeTaken = "2013-01-01T00:00:00Z"
			startDate = dt.strftime("%Y-%m-%dT%H:%M:%SZ")

	# old python date query code. probably can be deleted after natty works
	#cal = pdt.Calendar()
	#(fromPdt, index) = cal.parse(query)
	#timestamp = mktime(fromPdt)
	#print(fromPdt)
	#startDate = "2014-01-01T03:53:31Z"
	"""

	# get startDate from Natty
	nattyPort = "7999"
	nattyParams = { "q" : query }

	nattyUrl = "http://localhost:%s/?%s" % (nattyPort, urllib.urlencode(nattyParams)) 

	nattyResult = urllib2.urlopen(nattyUrl).read()

	if (nattyResult):
		nattyJson = json.loads(nattyResult)
		if (len(nattyJson) > 0):
			timestamp = nattyJson[0]["timestamps"][0]

			startDate = datetime.fromtimestamp(timestamp)

			usedText = nattyJson[0]["matchingValue"]
			query = query.replace(usedText, '')

	thumbnailBasepath = "/user_data/" + userId + "/"
	
	searchResults = SearchQuerySet().all()

	if (startDate):
		solrStartDate = startDate.strftime("%Y-%m-%dT%H:%M:%SZ")
		searchResults = searchResults.exclude(timeTaken__lte=solrStartDate)

	if (endDate):
		searchResults = searchResults.exclude(timeTaken__gte=endDate)

	#searchResults = searchResults.exclude(locationData__exact='{}')
	#searchResults = searchResults.exclude(timeTaken = Raw("['' TO *]"))

	for word in query.split():
		try:
			val = int(word)
		except ValueError:
			searchResults = searchResults.filter(content__contain=word)

	searchResults = searchResults.filter(userId=userId)[:10]

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

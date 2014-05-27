from django.shortcuts import render
from django.http import HttpResponse

from haystack.query import SearchQuerySet

from django.template import RequestContext, loader

import os, datetime
import json
from collections import OrderedDict

from photos.models import Photo, User, Classification
from photos import image_util, search_util, gallery_util, cluster_util
from .forms import ManualAddPhoto

from datetime import datetime, date
from dateutil.relativedelta import relativedelta
import time, math, urllib

	
def manualAddPhoto(request):
	form = ManualAddPhoto()

	context = {'form' : form}
	return render(request, 'photos/manualAddPhoto.html', context)

def search(request):
	# new webview code that's served in the iOS app
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return HttpResponse("Please specify a userId")

	if data.has_key('imagesize'):
		imageSize = int(data['imagesize'])
	else:
		imageSize = 78;

	width = imageSize*2 #doubled  for retina

	if data.has_key('threshold'):
		threshold = int(data['threshold'])
	else:
		threshold = 75;

	if data.has_key('dupthreshold'):
		dupThreshold = int(data['dupthreshold'])
	else:
		dupThreshold = 40

	if data.has_key('debug'):
		debug = True
		dupThreshold = -1
	else:
		debug = False

	if data.has_key('page'):
		page = int(data['page'])
	else:
		page = 1

	if data.has_key('r'):
		if (data['r'] == '1'):
			reverse = True
		else:
			reverse = False
	else:
		reverse = True

	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		return HttpResponse("User id " + str(userId) + " does not exist")

	thumbnailBasepath = "/user_data/" + str(user.id) + "/"

	if data.has_key('searchbox'):
		searchBox = True
	else:
		searchBox = False

	if data.has_key('q'):
		query = data['q']
	else:
		query = ''

	setSession(request, user.id)
	resultsDict = dict()

	allResults = SearchQuerySet().all().filter(userId=userId).order_by('timeTaken')
	resultsDict['indexSize'] = allResults.count()

	(startDate, newQuery) = search_util.getNattyInfo(query)

	if (resultsDict['indexSize'] > 0):
		if (startDate == None):
			startDate = allResults[0].timeTaken
		(pageStartDate, pageEndDate) = search_util.pageToDates(page, startDate, reverse)
		searchResults = search_util.solrSearch(user.id, pageStartDate, newQuery, pageEndDate)
		while (searchResults.count() < 25 and pageEndDate < datetime.utcnow() and pageStartDate >= startDate):
			if (reverse):
				pageStartDate = pageStartDate+relativedelta(months=-6)
			else:
				pageEndDate = pageEndDate+relativedelta(months=6)
			page +=1
			searchResults = search_util.solrSearch(user.id, pageStartDate, newQuery, pageEndDate)
		photoResults = gallery_util.splitPhotosFromIndexbyMonth(user.id, searchResults, threshold, dupThreshold, startDate=pageStartDate, endDate=pageEndDate)
		totalResults = searchResults.count()
		resultsDict['totalResults'] = totalResults
		resultsDict['photoResults'] = photoResults
		resultsDict['nextLink'] = '/api/search?user_id=' + str(user.id) + '&q=' + urllib.quote(query) + '&page=' + str(page+1) + '&r=' + str(int(reverse))

	resultsDict['reverse'] = reverse
	resultsDict['incompleteResults'] = search_util.incompletePhotos(user.id)

	context = {	'user' : user,
				'imageSize': imageSize,
				'resultsDict': resultsDict,
				'searchBox' : searchBox, 
				'debug' : debug,
				'query': query,
				'userId': userId,
				'thumbnailBasepath': thumbnailBasepath}
				
	return render(request, 'photos/search_webview.html', context)

def serveImage(request):
	if (request.session['userid']):
		userId = request.session['userid']
	else:
		return HttpResponse("Missing user id data")

	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	if data.has_key('photo'):
		photo = data['photo']
	else:
		return HttpResponse("Please specify a photo")


	thumbnailBasepath = "/user_data/" + str(userId) + "/"

	context = {	'photo': photo,
				'thumbnailBasepath': thumbnailBasepath}
	return render(request, 'photos/serve_image.html', context)

def userbaseSummary(request):
	knownPhoneIds = {	'AA94D207-D1E8-4098-9A39-76A3A1CC81FB',
						'BA8E652E-6BD4-4DC7-B8A0-7157FFA51DEC',
						'0012F94E-E6AF-429A-8530-E1011E1BFCAE',
						'CEE91F90-263A-4BF1-AED7-6AB27B7BC076',
						'F7092B08-EF4D-40EF-896D-0539CB102D3D',
						'3E8018C0-1BE5-483D-89C4-85CD66F81298',
						'26A1609E-BBBA-4684-8DF0-A394500FA96B',
						'BEEF'}
	resultList = list()
	for i in range(1000):
		userId = i
		try:
			user = User.objects.get(id=userId)
			entry = dict()
			entry['user'] = user
			dbQuery = Photo.objects.filter(user_id=user.id)
			totalCount = dbQuery.count()
			if (totalCount > 0):
				photoSet = dbQuery.order_by('-added')[:1]
				for photo in photoSet:
					entry['lastUploadTime'] = photo.added
					break
				entry['dbCount'] = totalCount
				entry['thumbsCount'] = dbQuery.exclude(thumb_filename=None).count()
				entry['thumbs'] = int(math.floor(entry['thumbsCount']/totalCount*100))
				photosWithGPS = dbQuery.filter(metadata__contains='{GPS}').count()

				if photosWithGPS > 0:
					entry['twofish'] = int(math.floor(float(dbQuery.exclude(twofishes_data=None).count())/float(photosWithGPS)*100))
				else:
					entry['twofish'] = '-'
				fullimagesCount = dbQuery.exclude(full_filename=None).count()
				entry['fullimagesCount'] = fullimagesCount
				entry['fullimages'] = entry['fullimagesCount']*100/totalCount
				searchResults = SearchQuerySet().all().filter(userId=userId)
				entry['resultsCount'] = searchResults.count()*100/totalCount
				entry['clusteredCount'] = dbQuery.exclude(clustered_time=None).count()
				entry['clustered'] = entry['clusteredCount']*100/totalCount

				if (fullimagesCount > 0):
					entry['classifications'] = dbQuery.exclude(classification_data=None).count()*100/fullimagesCount
				else:
					entry['classifications'] = 0
					
				entry['faces'] = dbQuery.exclude(faces_data=None).count()*100/totalCount
				entry['internal'] = False

				if (user.added == None or len(user.first_name) == 0):
					entry['internal'] = True
				else:
					for phoneid in knownPhoneIds:
						if ((phoneid.lower() in user.phone_id.lower()) or 
							('iphone simulator'.lower() in user.first_name.lower()) or
							('ipad simulator'.lower() in user.first_name.lower())):
							entry['internal'] = True
							break
			resultList.append(entry)
		except User.DoesNotExist:
			continue

	context = {	'resultList': resultList}
	return render(request, 'admin/userbaseSummary.html', context)

# Helper functions

def setSession(request, userId):
	request.session['userid'] = userId




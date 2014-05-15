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
import time, math

	
def manualAddPhoto(request):
	form = ManualAddPhoto()

	context = {'form' : form}
	return render(request, 'photos/manualAddPhoto.html', context)
	
def groups(request, user_id):
	try:
		user = User.objects.get(id=user_id)
	except User.DoesNotExist:
		return HttpResponse("User id " + str(user_id) + " does not exist")

	thumbnailBasepath = "/user_data/" + str(user.id) + "/"

	classifications = Classification.objects.select_related().filter(user_id = user.id)

	bucketedClasses = dict()
	photos = list()
	
	for classification in classifications:
		if classification.class_name not in bucketedClasses:
			bucketedClasses[classification.class_name] = list()
		bucketedClasses[classification.class_name].append(classification.photo)
		photos.append(classification.photo)
		

	numPhotos = len(set(photos))

	filteredBuckets = dict()

	for key, bucket in bucketedClasses.iteritems():
		if (len(bucket) > 2):
			filteredBuckets[key] = bucket

	sortedBuckets = OrderedDict(reversed(sorted(filteredBuckets.viewitems(), key=lambda x: len(x[1]))))
	
	context = {	'user' : user,
				'numPhotos': numPhotos,
				'sorted_buckets': sortedBuckets,
				'thumbnailBasepath': thumbnailBasepath}
	return render(request, 'photos/groups.html', context)


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

	if data.has_key('debug'):
		debug = True
	else:
		debug = False

	if data.has_key('threshold'):
		threshold = int(data['threshold'])
	else:
		threshold = 75;

	if data.has_key('dupthreshold'):
		dupThreshold = int(data['dupthreshold'])
	else:
		dupThreshold = 40

	if debug:
		dupThreshold = -1

	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		return HttpResponse("User id " + str(userId) + " does not exist")

	thumbnailBasepath = "/user_data/" + str(user.id) + "/"

	# if no searchbox flag, then must have query
	if data.has_key('searchbox'):
		searchBox = True
		if data.has_key('q'):
			query = data['q']
		else:
			query = ''
	else:
		searchBox = False
		if data.has_key('q'):
			query = data['q']
		else:
			return HttpResponse("Please specify a query")

	setSession(request, user.id)
	resultsDict = dict()

	resultsDict['indexSize'] = SearchQuerySet().all().filter(userId=userId).count()

	# if there is a query, send results through.
	if (query):
		(startDate, newQuery) = search_util.getNattyInfo(query)
		searchResults = search_util.solrSearch(user.id, startDate, newQuery)
		photoResults = gallery_util.splitPhotosFromIndexbyMonth(user.id, searchResults, threshold, dupThreshold)

		totalResults = searchResults.count()
		
		photoIdToThumb = dict()
		resultsDict['totalResults'] = totalResults
		resultsDict['photoResults'] = photoResults

	context = {	'user' : user,
				'imageSize': imageSize,
				'resultsDict': resultsDict,
				'searchBox' : searchBox, 
				'debug' : debug,
				'query': query,
				'userId': userId,
				'thumbnailBasepath': thumbnailBasepath}
				
	return render(request, 'photos/search_webview.html', context)

def gallery(request, user_id):
	try:
		user = User.objects.get(id=user_id)
	except User.DoesNotExist:
		return HttpResponse("User id " + str(user_id) + " does not exist")

	thumbnailBasepath = "/user_data/" + str(user.id) + "/"

	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	if data.has_key('imagesize'):
		imageSize = int(data['imagesize'])
	else:
		imageSize = 78;

	width = imageSize*2 #doubled  for retina

	if data.has_key('groupThreshold'):
		groupThreshold = int(data['groupThreshold'])
	else:
		groupThreshold = 11

	photoQuery = Photo.objects.filter(user_id=user.id)
	photos = gallery_util.splitPhotosFromDBbyMonth(user.id, photoQuery, groupThreshold)


	context = {	'user' : user,
				'imageSize': imageSize,
				'photos': photos,
				'thumbnailBasepath': thumbnailBasepath}
	return render(request, 'photos/gallery.html', context)



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
				entry['thumbs'] = int(math.floor(dbQuery.exclude(thumb_filename=None).count()/totalCount*100))
				photosWithGPS = dbQuery.filter(metadata__contains='{GPS}').count()

				if photosWithGPS > 0:
					entry['twofish'] = int(math.floor(float(dbQuery.exclude(twofishes_data=None).count())/float(photosWithGPS)*100))
				else:
					entry['twofish'] = '-'
				entry['fullimagesCount'] = dbQuery.exclude(full_filename=None).count()
				entry['fullimages'] = entry['fullimagesCount']*100/totalCount
				searchResults = SearchQuerySet().all().filter(userId=userId)
				entry['resultsCount'] = searchResults.count()*100/totalCount
				entry['clustered'] = dbQuery.exclude(clustered_time=None).count()*100/totalCount
				entry['classifications'] = dbQuery.exclude(classification_data=None).count()*100/totalCount
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

'''
Experimenting with deduping
'''

def dedup(request):
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return HttpResponse("Please specify a userId")

	if data.has_key('debug'):
		debug = True
	else:
		debug = False

	if data.has_key('threshold'):
		threshold = int(data['threshold'])
	else:
		threshold = 75

	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		return HttpResponse("User id " + str(userId) + " does not exist")

	thumbnailBasepath = "/user_data/" + str(user.id) + "/"

	path = '/home/derek/user_data/' + str(userId) + '/'
	photoQuery = Photo.objects.filter(user_id=user.id).order_by('time_taken')
	prevHist = list()
	prevPhotoFName = None
	prevThreshold = None

	histList = list()

	# iterate through images
	for photo in photoQuery:
		curHist = cluster_util.getSpatialHist(photo)

		addToCluster = False
		if (len(prevHist) == 0):
			# first image
			cluster = list()
			entry = dict()
			entry['photo'] = photo.id
			cluster.append(entry)
			prevHist.append(curHist)
		else:
			for hist in prevHist:
				dist = cluster_util.compHist(curHist, hist)
				if (dist < threshold):
					addToCluster = True
					break

			if (addToCluster):
				entry = dict()
				entry['photo'] = photo.id
				entry['dist'] = "%.2f"%dist
				cluster.append(entry)
				prevHist.append(curHist)
			else:
				histList.append(cluster)
				cluster = list()
				entry = dict()
				entry['photo'] = photo.id
				entry['dist'] = "%.2f"%dist
				cluster.append(entry)
				prevHist = list()
				prevHist.append(curHist)


	context = {	'histList': histList,
				'totalPhotos': photoQuery.count(),
				'totalSets': len(histList),
				'threshold': threshold,
				'thumbnailBasepath': thumbnailBasepath}
	return render(request, 'photos/dedup.html', context)


# Helper functions

def setSession(request, userId):
	request.session['userid'] = userId




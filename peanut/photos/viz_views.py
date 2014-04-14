from django.shortcuts import render
from django.http import HttpResponse

from haystack.query import SearchQuerySet

from django.template import RequestContext, loader

import os, datetime
import json
from collections import OrderedDict

from photos.models import Photo, User, Classification
from photos import image_util, search_util
from .forms import ManualAddPhoto

from datetime import datetime, date
from dateutil.relativedelta import relativedelta

	
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


def search(request, user_id=None):
	if (user_id):
		try:
			user = User.objects.get(id=user_id)
		except User.DoesNotExist:
			return HttpResponse("User id " + str(user_id) + " does not exist")

		thumbnailBasepath = "/user_data/" + str(user.id) + "/"

		numPhotos = Photo.objects.filter(user_id = user.id).count()

		context = {	'user' : user,
					'numPhotos': numPhotos,
					'thumbnailBasepath': thumbnailBasepath}
		return render(request, 'photos/search.html', context)
	else:
		if request.method == 'GET':
			data = request.GET
		elif request.method == 'POST':
			data = request.POST

		if data.has_key('user_id'):
			userId = data['user_id']
		else:
			return HttpResponse("Please specify a userId")

		if data.has_key('count'):
			count = int(data['count'])
		else:
			count = 48

		if data.has_key('page'):
			page = int(data['page'])
		else:
			page = 1

		if data.has_key('imagesize'):
			imageSize = int(data['imagesize'])
		else:
			imageSize = 78;

		if data.has_key('groupThreshold'):
			groupThreshold = int(data['groupThreshold'])
		else:
			groupThreshold = 1000;		


		width = imageSize*2 #doubled  for retina

		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			return HttpResponse("Phone id " + str(userId) + " does not exist")

		thumbnailBasepath = "/user_data/" + str(user.id) + "/"

		if data.has_key('q'):
			query = data['q']
		else:
			return HttpResponse("Please specify a query")

		setSession(request, user.id)

		(startDate, newQuery) = search_util.getNattyInfo(query)
		searchResults = search_util.solrSearch(user.id, startDate, newQuery)

		allResults = searchResults.count()
		#searchResults = searchResults[((page-1)*count):(count*page)]
		photoResults = splitPhotosFromIndexbyMonth(request, user.id, searchResults, groupThreshold)

		photoIdToThumb = dict()
		for result in searchResults:
			photoIdToThumb[result.photoId] = image_util.imageThumbnail(result.photoFilename, width, user.id)

		'''
		start = ((page-1)*count)+1
		if (allResults > count*page):
			end = count*page
			next = True
		else:
			end = allResults
			next = False

		if (start > 1):
			previous = True
		else:
			previous = False
		'''

		context = {	'user' : user,
					'imageSize': imageSize,
					'photoResults': photoResults,
					'resultSize': allResults,
					'query': query,
					'userId': userId,
					'thumbnailBasepath': thumbnailBasepath,
					'photoIdToThumb': photoIdToThumb}
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
	photos = splitPhotosFromDBbyMonth(request, user.id, photoQuery, groupThreshold)

	for entry in photos:
		for photo in entry['mainPhotos']:
			image_util.imageThumbnail(photo.new_filename, width, user.id)
		for photo in entry['subPhotos']:
			image_util.imageThumbnail(photo.new_filename, width, user.id)


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

# Helper functions

def splitPhotosFromDBbyMonth(request, userId, photoSet=None, groupThreshold=None):
	if (photoSet == None):
		photoSet = Photo.objects.filter(user_id=userId)

	if (groupThreshold == None):
		groupThreshold = 11

	dates = photoSet.datetimes('time_taken', 'month')
	
	photos = list()

	entry = dict()
	entry['date'] = 'Undated'
	entry['mainPhotos'] = list(photoSet.filter(time_taken=None)[:groupThreshold])
	entry['subPhotos'] = list(photoSet.filter(time_taken=None)[groupThreshold:])
	entry['count'] = len(entry['subPhotos'])
	photos.append(entry)

	for date in dates:
		entry = dict()
		entry['date'] = date.strftime('%b %Y')
		entry['mainPhotos'] = list(photoSet.exclude(time_taken=None).exclude(time_taken__lt=date).exclude(time_taken__gt=date+relativedelta(months=1)).order_by('time_taken')[:groupThreshold])
		entry['subPhotos'] = list(photoSet.exclude(time_taken=None).exclude(time_taken__lt=date).exclude(time_taken__gt=date+relativedelta(months=1)).order_by('time_taken')[groupThreshold:])
		entry['count'] = len(entry['subPhotos'])
		photos.append(entry)

	return photos

def splitPhotosFromIndexbyMonth(request, userId, photoSet=None, groupThreshold=None):
	if (photoSet == None):
		photoSet = 	SearchQuerySet().filter(userId=userId)

	if (groupThreshold == None):
		groupThreshold = 1000

	dateFacet = photoSet.date_facet('timeTaken', start_date=date(1900,1,1), end_date=date(2014,5,1), gap_by='month').facet('timeTaken', mincount=1, limit=-1, sort=False)
	facetCounts = dateFacet.facet_counts()
	
	photos = list()

	'''
	entry = dict()
	entry['date'] = 'Undated'
	entry['mainPhotos'] = list(photoSet.filter(timeTaken=None)[:groupThreshold])
	entry['subPhotos'] = list(photoSet.filter(timeTaken=None)[groupThreshold:])
	entry['count'] = len(entry['subPhotos'])
	photos.append(entry)
	'''
	print str(facetCounts['dates']['timeTaken'])
	del facetCounts['dates']['timeTaken']['start']
	del facetCounts['dates']['timeTaken']['end']
	del facetCounts['dates']['timeTaken']['gap']
	

	print facetCounts

	od = OrderedDict(sorted(facetCounts['dates']['timeTaken'].items()))

	for dateKey, countVal in od.items():

		print dateKey
		print countVal
		entry = dict()
		startDate = datetime.strptime(dateKey[:-1], '%Y-%m-%dT%H:%M:%S')
		entry['date'] = startDate.strftime('%b %Y')
		newDate = startDate+relativedelta(months=1)
		entry['photos'] = list(photoSet.exclude(timeTaken__lt=startDate).exclude(timeTaken__gt=newDate).order_by('timeTaken')[:groupThreshold])
		entry['count'] = len(entry['photos'])
		photos.append(entry)
		
	return photos

def setSession(request, userId):
	request.session['userid'] = userId




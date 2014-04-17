from django.shortcuts import render
from django.http import HttpResponse

from haystack.query import SearchQuerySet

from django.template import RequestContext, loader

import os, datetime
import json
from collections import OrderedDict

from photos.models import Photo, User, Classification
from photos import image_util, search_util, gallery_util
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
		# This is the original jquery mobile code
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

		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			return HttpResponse("Phone id " + str(userId) + " does not exist")

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

			totalResults = searchResults.count()
			photoResults = gallery_util.splitPhotosFromIndexbyMonth(user.id, searchResults)

			photoIdToThumb = dict()
			for result in searchResults:
				photoIdToThumb[result.photoId] = image_util.imageThumbnail(result.photoFilename, width, user.id)
			resultsDict['totalResults'] = totalResults
			resultsDict['photoResults'] = photoResults
			resultsDict['photoIdToThumb'] = photoIdToThumb

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

def setSession(request, userId):
	request.session['userid'] = userId




from django.shortcuts import render
from django.http import HttpResponse

from haystack.query import SearchQuerySet

from django.template import RequestContext, loader

import os, datetime
import json
from collections import OrderedDict

from photos.models import Photo, User, Classification
from photos import api_views, image_util
from .forms import ManualAddPhoto

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
		searchResults = api_views.coreSearch(request, user.id, query)
		width = imageSize*2 #doubled  for retina

		allResults = searchResults.count()
		searchResults = searchResults[((page-1)*count):(count*page)]

		for result in searchResults:
			image_util.imageThumbnail(result.photoFilename, width, user.id)

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


		context = {	'user' : user,
					'imageSize': imageSize,
					'start': start,
					'end': end,
					'resultSize': allResults,
					'next': next,
					'previous': previous,
					'searchResults': searchResults,
					'query': query,
					'page': page,
					'userId': userId,
					'thumbnailBasepath': thumbnailBasepath}
		return render(request, 'photos/search_webview.html', context)



def gallery(request, user_id):
	try:
		user = User.objects.get(id=user_id)
	except User.DoesNotExist:
		return HttpResponse("User id " + str(user_id) + " does not exist")

	thumbnailBasepath = "/user_data/" + str(user.id) + "/"


	photos = Photo.objects.filter(user_id = user.id)
	numPhotos = photos.count()


	context = {	'user' : user,
				'numPhotos': numPhotos,
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


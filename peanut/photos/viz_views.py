from django.shortcuts import render
from django.http import HttpResponse
from django.utils import timezone

from haystack.query import SearchQuerySet

from django.template import RequestContext, loader

import os, datetime
import json
from collections import OrderedDict

from photos.models import Photo, User, Classification
from photos import api_views

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

		if data.has_key('phone_id'):
			phoneId = data['phone_id']
		else:
			return HttpResponse("Please specify a phoneId")

		if data.has_key('count'):
			count = data['count']
		else:
			count = 10

		try:
			user = User.objects.get(phone_id=phoneId)
		except User.DoesNotExist:
			return HttpResponse("Phone id " + str(phoneId) + " does not exist")

		thumbnailBasepath = "/user_data/" + str(user.id) + "/"


		if data.has_key('q'):
			query = data['q']
		else:
			return HttpResponse("Please specify a query")

		searchResults = api_views.coreSearch(request, user.id, query)

		context = {	'user' : user,
					'count': count,
					'searchResults': searchResults[:count],
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


import parsedatetime as pdt
import os, sys
import json
import subprocess
from PIL import Image
import time
import logging
import thread
import urllib2
import pprint
import datetime
import HTMLParser
import operator
import pytz
import uuid
from random import randint
from collections import Counter

from django.shortcuts import render
from django.template.loader import render_to_string
from django.http import HttpResponse
from django.core import serializers
from django.utils import timezone
from django.db.models import Count, Q
from django.db import IntegrityError
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.template import RequestContext, loader
from django.utils import timezone
from django.forms.models import model_to_dict
from django.http import Http404
from django.contrib.gis.geos import Point, fromstr

from haystack.query import SearchQuerySet

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response

from common.models import Photo, User, Similarity
from common.serializers import PhotoSerializer, UserSerializer
from common import api_util, cluster_util

from peanut.settings import constants

from arbus import image_util, search_util, suggestions_util
from arbus.forms import SearchQueryForm

import urllib
from dateutil.relativedelta import relativedelta

logger = logging.getLogger(__name__)

"""
	Autocomplete which takes in user_id and q and returns back matches and counts
"""
@csrf_exempt
def autocomplete(request):
	startTime = time.time()
	data = api_util.getRequestData(request)
	htmlParser = HTMLParser.HTMLParser()
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return api_util.returnFailure(response, "Need user_id")

	if data.has_key('q'):
		query = htmlParser.unescape(data['q'])
	else:
		return api_util.returnFailure(response, "Need q")

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
		countPhrase = getCountPhrase(count)
		entry = {'name': phrase, 'count': count, 'count_phrase': countPhrase, 'order': order}
		order += 1
		results.append(entry)

	if ('settings'.startswith(query.lower())):
		entry = {'name': 'settings', 'count': 1, 'count_phrase': 1, 'order': order}
		results.append(entry)

	# Make sure you return a JSON object, not a bare list.
	# Otherwise, you could be vulnerable to an XSS attack.
	responseJson = json.dumps({
		'results': results,
		'query_time': (time.time() - startTime),
	})

	
	return HttpResponse(responseJson, content_type='application/json')

"""
Search API

Takes in a query, number of entries to fetch, and a startDate (all fields in forms.py SearchQueryForm)

"""
@csrf_exempt
def search(request):
	response = dict()

	form = SearchQueryForm(request.GET) # A form bound to the POST data
	if form.is_valid(): # All validation rules pass
		query = form.cleaned_data['q']
		user_id = form.cleaned_data['user_id']
		startDateTime = form.cleaned_data['start_date_time']
		num = form.cleaned_data['num']
		# Reversed
		r = form.cleaned_data['r']
		docstack = form.cleaned_data['docstack']
		
		# See if out query has a time associated within it
		(nattyStartDate, newQuery) = search_util.getNattyInfo(query)

		if not startDateTime:
			if (nattyStartDate):
				startDateTime = nattyStartDate
			else:
				startDateTime = datetime.date(1901,1,1)
		
		# Get a search for 2 times the number of entries we want to return, we will filter it down loater
		if (query == "''" and docstack):
			searchResults = search_util.solrSearch(user_id, startDateTime, newQuery, reverse = r, limit=num*2, exclude='docs screenshot')
			docResults = search_util.solrSearch(user_id, startDateTime, 'docs screenshot', reverse = r, limit=num, operator='OR')
		else:
			searchResults = search_util.solrSearch(user_id, startDateTime, newQuery, reverse = r, limit = num*2)
			docResults = None

		if (len(searchResults) > 0 or docResults and len(docResults) > 0):	
			# Group into months
			monthGroupings = cluster_util.splitPhotosFromIndexbyMonth(user_id, searchResults, docResults=docResults)

			# Grap the objects to turn into json, called sections.  Also limit by num and get the lastDate
			#   which is the key for the next call
			sections = api_util.turnFormattedGroupsIntoSections(monthGroupings, num)

			response['objects'] = sections
		else:
			response['retry_suggestions'] = suggestions_util.getTopCombos(user_id)
		response['result'] = True
		return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

	else:
		response['result'] = False
		response['errors'] = json.dumps(form.errors)
		return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")


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

	data = api_util.getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
	else:
		return api_util.returnFailure(response, "Need user_id")

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
def get_user(request, productId = 0):
	response = dict({'result': True})
	user = None
	data = api_util.getRequestData(request)
	
	if data.has_key('user_id'):
		userId = data['user_id']
		user = User.objects.get(id=userId)
	
	if data.has_key('phone_id'):
		phoneId = data['phone_id']
		try:
			user = User.objects.get(Q(phone_id=phoneId) & Q(product_id=productId))
		except User.DoesNotExist:
			logger.error("Could not find user: %s %s" % (phoneId, productId))
			return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

	#if user is None:
	#	return returnFailure(response, "User not found.  Need valid user_id or phone_id")

	if (user):
		serializer = UserSerializer(user)
		response['user'] = serializer.data
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

"""
	Creates a new user, if it doesn't exist
"""

@csrf_exempt
def create_user(request, productId = 0):
	response = dict({'result': True})
	user = None
	data = api_util.getRequestData(request)

	if data.has_key('device_name'):
		firstName =  data['device_name']
	else:
		firstName = ""

	if data.has_key('phone_id'):
		phoneId = data['phone_id']
		try:
			user = User.objects.get(Q(phone_id=phoneId) & Q(product_id=productId))
			return api_util.returnFailure(response, "User already exists")
		except User.DoesNotExist:
			user = createUser(phoneId, firstName, productId)
	else:
		return api_util.returnFailure(response, "Need a phone_id")

	serializer = UserSerializer(user)
	response['user'] = serializer.data
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

"""
Helper functions
"""
	
"""
	Utility method to create a user in the database and create all needed file top_locations
	for the image pipeline

	This could be located else where
"""
def createUser(phoneId, firstName, productId):
	user = User(display_name = firstName, phone_id = phoneId, product_id = productId)
	user.save()

	userBasePath = user.getUserDataPath()

	try:
		os.stat(userBasePath)
	except:
		os.mkdir(userBasePath)
		os.chmod(userBasePath, 0775)

	return user

def getCountPhrase(count):
	if count == 0:
		return ""
	elif count == 1:
		return "1"
	elif count < 5:
		return "2+"
	elif count < 10:
		return "5+"
	elif count < 50:
		return "20+"
	elif count < 150:
		return "50+"
	else:
		return "100+"

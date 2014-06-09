import datetime

from django.db.models import Count

from haystack.query import SearchQuerySet

from common.models import Photo, User
from arbus import search_util

"""
	Fetches all photos for the given user and returns back the all non-state and non-country
	location names

	returns back list of dicts with:
	name, count, order
"""
def getTopLocations(userId, limit=None):
	sqs = SearchQuerySet().filter(userId=userId)
	queryResult = sqs.facet('locations').facet_counts()
	order = 0
	photoLocations = list()

	for location in queryResult["fields"]["locations"]:
		if (location[1] > 0):
			if (location[0].lower() not in 'united states'):
				entry = dict()
				entry['name'] = location[0]
				entry['count'] = location[1]
				entry['order'] = order
				order += 1
				photoLocations.append(entry)
	
	sortedList = sorted(photoLocations, key=lambda k: k['count'], reverse=True)

	if (limit):
		sortedList = sortedList[:limit]

	return sortedList

"""
	Fetches all photos for the given user and returns back top categories with count.
	returns back list of dicts with:
	name, count, order
"""
def getTopCategories(userId, limit=None):
	sqs = SearchQuerySet().filter(userId=userId)
	queryResult = sqs.facet('classes').facet_counts()
	order = 0
	classesList = list()
	
	for classResult in queryResult["fields"]["classes"]:
		if (classResult[1] > 0):
			entry = dict()
			entry['name'] = classResult[0]
			entry['count'] = classResult[1]
			entry['order'] = order
			order += 1
			classesList.append(entry)

	if (limit):
		classesList = classesList[:limit]
		
	return classesList

"""
	Fetches all photos for the given user and returns back top time searches with count. Currently, faking it.
	returns back list of dicts with:
	name, count, order
"""
def getTopTimes(userId):

	# generate last month str
	lastMonthStr = (datetime.datetime.utcnow()- datetime.timedelta(seconds=2592000)).strftime('%b %Y')
	timeQueries = ['last week', lastMonthStr.lower(), 'last summer', '6 months ago', 'last year']
	order = 0
	sugList = list()
	for timeQuery in timeQueries:
		(startDate, newQuery) = search_util.getNattyInfo(timeQuery)
		count = search_util.solrSearch(userId, startDate, '').count()
		if (count > 0):
			entry = dict()
			entry['name'] = timeQuery
			entry['count'] = count
			entry['order'] = order
			order += 1
			sugList.append(entry)
	return sugList

"""
	Used to return combos of term that might have results in database
"""
def getTopCombos(userId, limit=None):

	timeQueries = ['last fall', 'last summer', '6 months ago', 'last year']

	topLocations = getTopLocations(userId, limit=10)
	topCategories = getTopCategories(userId, limit=10)

	comboList = list()

	for i in range(len(topLocations[:3])):
		query = topLocations[i]['name'] + ' ' + timeQueries[i]
		(startDate, newQuery) = search_util.getNattyInfo(query)
		count = search_util.solrSearch(userId, startDate, newQuery).count()
		if (count > 0):
			entry = dict()
			entry['name'] = query
			entry['count'] = count
			comboList.append(entry)

	for i in range(len(topCategories[:3])):
		query = topCategories[i]['name'] + ' ' + timeQueries[i]
		(startDate, newQuery) = search_util.getNattyInfo(query)
		count = search_util.solrSearch(userId, startDate, newQuery).count()
		if (count > 0):
			entry = dict()
			entry['name'] = query
			entry['count'] = count
			comboList.append(entry)


	sortedList = sorted(comboList, key=lambda k: k['count'], reverse=True)

	order = 0
	for entry in sortedList:
		entry['order'] = order
		order += 1

	if (limit):
		sortedList = sortedList[:limit]
	return sortedList




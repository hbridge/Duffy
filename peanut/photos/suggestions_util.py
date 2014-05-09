import datetime

from django.db.models import Count

from photos.models import Photo, User
from photos import search_util


"""
	Fetches all photos for the given user and returns back the all cities with their counts.  Results are
	unsorted.

"""
def getTopLocations(userId):

	queryResult = Photo.objects.filter(user_id=userId).values('location_city').order_by().annotate(Count('location_city')).order_by('-location_city__count')
	
	photoLocations = list()
	for location in queryResult:
		if (location['location_city__count'] > 0):
			entry = dict()
			entry['name'] = location['location_city']
			entry['count'] = location['location_city__count']
			photoLocations.append(entry)
	
	sortedList = sorted(photoLocations, key=lambda k: k['count'], reverse=True)
	index = 1
	for entry in sortedList:
		entry['order'] = index
		index += 1

	return sortedList

"""
	Fetches all photos for the given user and returns back top categories with count. Currently, faking it.

"""
def getTopCategories(userId):

	catQueries = ['screenshots', 'people', 'food', 'animals', 'car']
	order = 1
	sugList = list()
	for catQuery in catQueries:
		count = search_util.solrSearch(userId, None, catQuery).count()
		if (count > 0):
			entry = dict()
			entry['name'] = catQuery
			entry['count'] = count
			entry['order'] = order
			order += 1
			sugList.append(entry)
	return sugList



"""
	Fetches all photos for the given user and returns back top time searches with count. Currently, faking it.

"""
def getTopTimes(userId):

	# generate last month str
	lastMonthStr = (datetime.datetime.utcnow()- datetime.timedelta(seconds=2592000)).strftime('%b %Y')
	timeQueries = ['last week', lastMonthStr.lower(), 'last summer', '6 months ago', 'last year']
	order = 1
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



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

	return [{'name': 'people', 'count': 1, 'order': 1},
			{'name': 'food', 'count': 8, 'order': 2}, 
			{'name': 'screenshots', 'count': 6, 'order': 3}, 
			{'name': 'animal', 'count': 4, 'order': 4}, 
			{'name': 'car', 'count': 2, 'order':5}]



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



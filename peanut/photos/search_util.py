import json
import datetime
import dateutil.parser
import urllib2
import urllib

from haystack.query import SearchQuerySet

from photos.models import Photo

"""
	Helper method to get a startDate and a new filtered query from Natty.
	This makes a url call to the Natty server that gets back the timestamp around a 
	time phrase like "last week" then also gives us the words used, which are then
	removed from the query.

	Returns: Tuple of (startDate, newQuery)

"""
def getNattyInfo(query):
	# get startDate from Natty
	nattyPort = "7999"
	nattyParams = { "q" : query }

	nattyUrl = "http://localhost:%s/?%s" % (nattyPort, urllib.urlencode(nattyParams)) 

	nattyResult = urllib2.urlopen(nattyUrl).read()

	if (nattyResult):
		nattyJson = json.loads(nattyResult)
		if (len(nattyJson) > 0):
			timestamp = nattyJson[0]["timestamps"][0]

			startDate = datetime.datetime.fromtimestamp(timestamp)

			usedText = nattyJson[0]["matchingValue"]
			newQuery = query.replace(usedText, '')
			
			return (startDate, newQuery)
	return (None, query)

"""
	Send a request to the Solr search index.  This filters by the userId and grabs everything
	after the requested startDate
"""
def solrSearch(userId, startDate, query, reverse=False, limit=None, endDate=datetime.datetime.utcnow()):
	searchResults = SearchQuerySet().all().filter(userId=userId)

	if (startDate):
		solrStartDate = startDate.strftime("%Y-%m-%dT%H:%M:%SZ")
		searchResults = searchResults.exclude(timeTaken__lte=solrStartDate)
		if not limit:
			searchResults = searchResults.exclude(timeTaken__gte=endDate.strftime("%Y-%m-%dT%H:%M:%SZ"))
	else:
		searchResults = searchResults.exclude(timeTaken__gte=endDate.strftime("%Y-%m-%dT%H:%M:%SZ"))

	for word in query.split():
		searchResults = searchResults.filter(content__contain=word)

	if not reverse:
		searchResults = searchResults.order_by('timeTaken')
	else:
		searchResults = searchResults.order_by('-timeTaken')

	if limit:
		searchResults = searchResults[:limit]
	
	return searchResults

"""
	Returns first n months
"""
def getNMonthsOut(startDate, nMonths):
	month = startDate.month + nMonths - 1
	year = startDate.year + month/12
	month = month % 12 + 1
	day = 1
	return datetime.datetime(year,month,day, 0, 0, 0)

"""
	Given a "page", returns starts and end dates of this page
"""
def pageToDates(page, origStartDate, reversed=False):
	if (reversed):
		pageSize = 6 #Number of months; shorter window for full gallery view
	else:
		pageSize = 6 #could do a longer window for searches

	if (reversed):
		dateNow = datetime.datetime.utcnow()
		if (page > 1):
			pageEndDate = getNMonthsOut(dateNow, -1*pageSize*(page-1))
		else:
			pageEndDate = datetime.datetime.utcnow()
		pageStartDate = getNMonthsOut(dateNow, -1*pageSize*page)
		return (pageStartDate, pageEndDate)
	else:
		if (page > 1):
			pageStartDate = getNMonthsOut(origStartDate, pageSize*(page-1))
		else:
			pageStartDate = origStartDate
		pageEndDate = getNMonthsOut(origStartDate, pageSize*page)
		return (pageStartDate, pageEndDate)

"""
	Returns false if searchResults are incomplete
"""
def incompletePhotos(userId):
	if Photo.objects.filter(user_id=userId).filter(full_filename=None).count() > 20:
		return True
	return False

"""
	Returns the last updated time for search searchResults
"""
def lastUpdatedSearchResults(userId):
	allResults = SearchQuerySet().all().filter(userId=userId).order_by('-updated')
	if (allResults.count() > 0):
		return allResults.order_by('-updated')[0].updated
	else:
		return None

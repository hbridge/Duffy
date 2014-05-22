import json
import datetime

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
def solrSearch(userId, startDate, query, endDate=datetime.datetime.utcnow()):
	searchResults = SearchQuerySet().all().filter(userId=userId)

	if (startDate):
		solrStartDate = startDate.strftime("%Y-%m-%dT%H:%M:%SZ")
		searchResults = searchResults.exclude(timeTaken__lte=solrStartDate).exclude(timeTaken__gte=endDate.strftime("%Y-%m-%dT%H:%M:%SZ"))
	else:
		searchResults = searchResults.exclude(timeTaken__gte=endDate.strftime("%Y-%m-%dT%H:%M:%SZ"))

	for word in query.split():
		searchResults = searchResults.filter(content__contain=word)

	searchResults = searchResults.order_by('timeTaken')
	
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
def pageToDates(page, origStartDate):
	if (page > 1):
		pageStartDate = getNMonthsOut(origStartDate, 3*(page-1))
	else:
		pageStartDate = origStartDate
	pageEndDate = getNMonthsOut(origStartDate, 3*page)
	return (pageStartDate, pageEndDate)

"""
	Returns false if searchResults are incomplete
"""
def areSearchResultsComplete(userId):
	if (Photo.objects.filter(user_id=userId).filter(full_filename=None).count() > 0):
		return False
	return True

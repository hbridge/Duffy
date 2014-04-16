import json
from datetime import datetime

import urllib2
import urllib

from haystack.query import SearchQuerySet

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

			startDate = datetime.fromtimestamp(timestamp)

			usedText = nattyJson[0]["matchingValue"]
			newQuery = query.replace(usedText, '')
			
			return (startDate, newQuery)
	return (None, query)

"""
	Send a request to the Solr search index.  This filters by the userId and grabs everything
	after the requested startDate
"""
def solrSearch(userId, startDate, query):
	searchResults = SearchQuerySet().all().filter(userId=userId)

	if (startDate):
		solrStartDate = startDate.strftime("%Y-%m-%dT%H:%M:%SZ")
		searchResults = searchResults.exclude(timeTaken__lte=solrStartDate)

	for word in query.split():
		print word
		searchResults = searchResults.filter(content__contain=word)

	searchResults = searchResults.order_by('timeTaken')
	
	return searchResults

import json
import datetime
import dateutil.parser
import urllib2
import urllib



"""
	Helper method to get a startDate and a new filtered query from Natty.
	This makes a url call to the Natty server that gets back the timestamp around a 
	time phrase like "last week" then also gives us the words used, which are then
	removed from the query.

	Returns: Tuple of (startDate, newQuery)

"""
def getNattyInfo(query):
	# get startDate from Natty
	nattyPort = "7990"
	nattyParams = { "q" : query }

	nattyUrl = "http://localhost:%s/?%s" % (nattyPort, urllib.urlencode(nattyParams)) 

	nattyResult = urllib2.urlopen(nattyUrl).read()

	if (nattyResult):
		nattyJson = json.loads(nattyResult)
		if (len(nattyJson) > 0):
			timestamp = nattyJson[0]["timestamps"][0]

			startDate = datetime.datetime.fromtimestamp(timestamp)

			usedText = nattyJson[0]["matchingValue"]
			newQuery = query.replace(usedText, '').strip()
			newQuery = newQuery.replace('  ', ' ')

			relative = "RELATIVE_TIME" in nattyJson[0]["syntaxTree"]
			
			return (startDate, newQuery, usedText, relative)
	return (None, query, False)

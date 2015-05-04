import json
import datetime
import dateutil.parser
import urllib2
import urllib
from urllib2 import URLError
import pytz
#from peanut.settings import constants
from django.conf import settings

"""
	Helper method to get a startDate and a new filtered query from Natty.
	This makes a url call to the Natty server that gets back the timestamp around a
	time phrase like "last week" then also gives us the words used, which are then
	removed from the query.

	Returns: Tuple of (startDate, newQuery)

"""
def getNattyInfo(query, timezone):
	# get startDate from Natty
	nattyPort = "7990"
	nattyParams = { "q" : query }

	if timezone:
		nattyParams["tz"] = timezone
	nattyUrl = "http://localhost:%s/?%s" % (nattyPort, urllib.urlencode(nattyParams))
	if hasattr(settings,"LOCAL"):
		nattyUrl = "http://dev.duffyapp.com:%s/?%s" % (nattyPort, urllib.urlencode(nattyParams))

	try:
		nattyResult = urllib2.urlopen(nattyUrl).read()
	except URLError as e:
		print "Could not connect to Natty: %s" % (e.strerror)
		nattyResult = None

	if (nattyResult):
		nattyJson = json.loads(nattyResult)
		if (len(nattyJson) > 0):
			timestamp = nattyJson[0]["timestamps"][0]

			startDate = datetime.datetime.fromtimestamp(timestamp).replace(tzinfo=pytz.utc)

			usedText = nattyJson[0]["matchingValue"]
			newQuery = query.replace(usedText, '').strip()
			newQuery = newQuery.replace('  ', ' ')

			return (startDate, newQuery, usedText)
	return (None, query, None)

import json
import datetime
import urllib2
import urllib
import logging
from urllib2 import URLError
import pytz
from django.conf import settings

logger = logging.getLogger(__name__)


# Helper method to get a startDate and a new filtered query from Natty.
# This makes a url call to the Natty server that gets back the timestamp around a
# time phrase like "last week" then also gives us the words used, which are then
# removed from the query.
#
# Returns: [Tuple of (startDate, usedText)]  (list of tuples)
def getNattyInfo(query, timezone):
	myResults = list()
	results = processQuery(query, timezone)

	# Get the base results
	myResults.extend(results)

	# Now loop through all results and find all sub results.  Then return these
	# with the usedText taken out of the original query
	# query:  book meeting with Andrew for tues morning in two hours
	# newQuery: book meeting with Andrew for in two hours
	# Return: book meeting with Andrew for tues morning  (two hours from now)
	for result in results:
		startDate, newQuery, usedText = result

		subResults = getNattyInfo(newQuery, timezone)

		for subResult in subResults:
			subDate, subNewQuery, subUsedText = subResult

			myResults.append((subDate, getNewQuery(query, subUsedText), subUsedText))

	# Sort by the date, we want to soonest first
	myResults = sorted(myResults, key=lambda x: x[0])

	# prefer anything that has "at" in the text
	myResults = sorted(myResults, key=lambda x: "at" in x[2], reverse=True)

	return myResults


def processQuery(query, timezone):
	# get startDate from Natty
	nattyPort = "7990"
	# converting back to utf-8 for urllib
	nattyParams = {"q": unicode(query).encode('utf-8')}

	if timezone:
		nattyParams["tz"] = str(timezone)

	nattyUrl = "http://localhost:%s/?%s" % (nattyPort, urllib.urlencode(nattyParams))

	# TODO: Move this to a cleaner solution
	if hasattr(settings, "LOCAL"):
		nattyUrl = "http://dev.duffyapp.com:%s/?%s" % (nattyPort, urllib.urlencode(nattyParams))

	try:
		nattyResult = urllib2.urlopen(nattyUrl).read()
	except URLError as e:
		logger.error("Could not connect to Natty: %s" % (e.strerror))
		nattyResult = None

	result = list()

	if (nattyResult):
		nattyJson = json.loads(nattyResult)
		for entry in nattyJson:
			timestamp = entry["timestamps"][0]
			startDate = datetime.datetime.fromtimestamp(timestamp).replace(tzinfo=pytz.utc)

			usedText = entry["matchingValue"]

			now = datetime.datetime.now(pytz.utc)
			# If we pulled out just an int less than 12, then pick the next time that time number happens.
			# So if its currently 14, and they say 8... then add
			if startDate < (now - datetime.timedelta(seconds=10)) and startDate > now - datetime.timedelta(hours=24):
				# If it has am or pm in the used text, then assume tomorrow
				if "m" in usedText:
					startDate = startDate + datetime.timedelta(days=1)
				else:
					# otherwise, its 8 so assume 12 hours from now
					startDate = startDate + datetime.timedelta(hours=12)

			column = entry["column"]
			newQuery = getNewQuery(query, usedText, column)

			result.append((startDate, newQuery, usedText))
	return result


def representsInt(s):
	try:
		int(s)
		return True
	except ValueError:
		return False


# This method takes the query and usedText and returns back the query without the usedText in it
# The column is where the phase starts if its defined
def getNewQuery(query, usedText, column=None):
	if column:
		newQuery = query[:column - 1] + query[column - 1 + len(usedText):]
	else:
		newQuery = query.replace(usedText, '')
	newQuery = newQuery.replace('  ', ' ').strip()

	return newQuery

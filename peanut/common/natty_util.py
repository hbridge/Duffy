import json
import datetime
import urllib2
import urllib
import logging
from urllib2 import URLError
import pytz
from django.conf import settings

logger = logging.getLogger(__name__)


class NattyResult():
	utcTime = None
	queryWithoutTiming = None
	textUsed = None
	hadDate = None
	hadTime = None

	def __init__(self, utcTime, queryWithoutTiming, textUsed, hadDate, hadTime):
		self.utcTime = utcTime
		self.queryWithoutTiming = queryWithoutTiming
		self.textUsed = textUsed
		self.hadDate = hadDate
		self.hadTime = hadTime


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
		subResults = getNattyInfo(result.queryWithoutTiming, timezone)

		for subResult in subResults:
			subResultUsedText = subResult.textUsed
			subResult.queryWithoutTiming = getNewQuery(query, subResultUsedText)

			myResults.append(subResult)

	# Sort by the date, we want to soonest first
	myResults = sorted(myResults, key=lambda x: x.utcTime)

	# prefer anything that has "at" in the text
	# Make sure it's "at " (with a space) since Saturday will match
	myResults = sorted(myResults, key=lambda x: "at " in x.textUsed, reverse=True)

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
			timestamp = entry["timestamps"][-1]
			startDate = datetime.datetime.fromtimestamp(timestamp).replace(tzinfo=pytz.utc)

			usedText = entry["matchingValue"]

			now = datetime.datetime.now(pytz.utc)
			# If we pulled out just an int less than 12, then pick the next time that time number happens.
			# So if its currently 14, and they say 8... then add
			if startDate < (now - datetime.timedelta(seconds=10)) and startDate > now - datetime.timedelta(hours=24):

				# If it has am or pm in the used text, then assume tomorrow
				if "m" in usedText.lower():
					startDate = startDate + datetime.timedelta(days=1)
				else:
					# otherwise, its 8 so assume 12 hours from now
					startDate = startDate + datetime.timedelta(hours=12)

			tzAwareStartDate = startDate.astimezone(timezone)
			# If we think tho that its super early in the morning and there's no am, we're probably wrong, so set it later
			if tzAwareStartDate.hour >= 0 and tzAwareStartDate.hour < 6 and "am" not in usedText.lower():
				startDate = startDate + datetime.timedelta(hours=12)

			column = entry["column"]
			newQuery = getNewQuery(query, usedText, column)

			result.append(NattyResult(startDate, newQuery, usedText, None, None))
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

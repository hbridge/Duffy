import json
import datetime
import urllib2
import urllib
import re
import logging
from urllib2 import URLError
import pytz
from dateutil import relativedelta

from django.conf import settings

from common import date_util

logger = logging.getLogger(__name__)


class NattyResult():
	utcTime = None
	queryWithoutTiming = None
	textUsed = None
	hadDate = None
	hadTime = None
	isToday = None

	def __init__(self, utcTime, queryWithoutTiming, textUsed, hadDate, hadTime):
		self.utcTime = utcTime
		self.queryWithoutTiming = queryWithoutTiming
		self.textUsed = textUsed
		self.hadDate = hadDate
		self.hadTime = hadTime

	def validTime(self):
		return self.hadDate or self.hadTime

	def __str__(self):
		return "=%s '%s' '%s' hadDate:%s hadTime:%s=" % (self.utcTime, self.queryWithoutTiming, self.textUsed, self.hadDate, self.hadTime)


# Main External method
def getNattyResult(msg, user):
	nattyMsg = fixMsgForNatty(msg, user)
	nattyResults = getNattyInfo(nattyMsg, user.getTimezone())

	if len(nattyResults) == 0:
		return None

	now = date_util.now(pytz.utc)

	startlen = len(nattyResults)
	nattyResults = filter(lambda x: x.utcTime >= now - datetime.timedelta(seconds=10), nattyResults)
	endlen = len(nattyResults)

	if startlen != endlen:
		logger.debug("User %s: Filtered out %s entries due to them being behind in time. Have %s left" % (user.id, startlen - endlen, endlen))

	# Sort by the date, we want to soonest first
	nattyResults = sorted(nattyResults, key=lambda x: x.utcTime)

	# Sort by if there was a time in the date or not
	nattyResults = sorted(nattyResults, key=lambda x: 0 if x.hadTime else 1)

	# prefer anything that has "at" in the text
	# Make sure it's "at " (with a space) since Saturday will match
	nattyResults = sorted(nattyResults, key=lambda x: "at " in x.textUsed, reverse=True)

	# Filter out stuff that was only using term "now"
	startlen = len(nattyResults)
	nattyResults = filter(lambda x: x.textUsed.lower() != "now", nattyResults)
	endlen = len(nattyResults)

	if startlen != endlen:
		logger.debug("User %s: Filtered out %s entries due them having 'now' in them. Have %s left" % (user.id, startlen - endlen, endlen))

	if len(nattyResults) == 0:
		return None

	# Filter down our results to be unique based on timestamp
	uniqueDates = set()
	uniqueResults = list()
	for n in nattyResults:
		if n.utcTime not in uniqueDates:
			uniqueResults.append(n)
			uniqueDates.add(n.utcTime)

	# Handle scenarios where someone types a date and time in seperate parts of the message
	# We look for results where one has a date, and one has a time...then combine them
	# NOTE: This doesn't handle things like "remind me to poop at 7am every monday" said on a Monday
	# Because natty returns the "next" monday.
	if len(uniqueResults) == 2:
		timeResult = None
		dateResult = None
		if (uniqueResults[0].hadTime and not uniqueResults[0].hadDate and
						uniqueResults[1].hadDate and not uniqueResults[1].hadTime):
			timeResult = uniqueResults[0]
			dateResult = uniqueResults[1]
		elif (uniqueResults[1].hadTime and not uniqueResults[1].hadDate and
								uniqueResults[0].hadDate and not uniqueResults[0].hadTime):
			timeResult = uniqueResults[1]
			dateResult = uniqueResults[0]

		if timeResult and dateResult:
			combinedDt = datetime.datetime(dateResult.utcTime.year, dateResult.utcTime.month, dateResult.utcTime.day, timeResult.utcTime.hour, timeResult.utcTime.minute, timeResult.utcTime.second).replace(tzinfo=pytz.utc)
			combinedQuery = replace(timeResult.queryWithoutTiming, dateResult.textUsed, "")
			combinedUsedText = dateResult.textUsed + " " + timeResult.textUsed

			combinedNattyResult = NattyResult(combinedDt, combinedQuery, combinedUsedText, True, True)
			logger.debug("User %s: Combined two times %s %s to create %s" % (user.id, uniqueResults[0], uniqueResults[1], combinedNattyResult))
			return combinedNattyResult

	return nattyResults[0]


def replace(msg, toRemove, toPutIn):
	swap = re.compile(toRemove, re.IGNORECASE)
	return swap.sub(toPutIn, msg)


# Remove and replace troublesome strings for Natty
# This is meant to just be used to change up the string for processing, not used later for
def fixMsgForNatty(msg, user):
	newMsg = msg

	# Remove these words if they show up with timing info, like:
	# Remind me today before 6 turns into today 6
	words = {
		"around": "at",
		"before": "at",
		"after": "at",
		"by": "at",
		"for": "",  # For an hour
	}

	for word, replaceWith in words.iteritems():
		search = re.search(r'\b(?P<phrase>%s ?[0-9]+)' % word, newMsg, re.IGNORECASE)

		if search:
			phrase = search.group("phrase")
			newPhrase = replace(phrase, word, replaceWith).strip()
			newMsg = replace(newMsg, phrase, newPhrase)

	# Remove o'clock
	newMsg = replace(newMsg, "o'clock", "")
	newMsg = replace(newMsg, "oclock", "")

	# This might cause issues if there's an email address or other things using @
	# Need trailing space incase they do @230
	newMsg = replace(newMsg, "@", "at ")

	# Make sure there's only 1 space between things, because a few regexes require that
	newMsg = replace(newMsg, "  ", " ")

	# Fix "again at 3" situation where natty doesn't like that...wtf
	againAt = re.search(r'\bagain at ([0-9])', newMsg, re.IGNORECASE)
	if againAt:
		newMsg = replace(newMsg, "again at", "at")

	# WTF hack. Natty doesn't like appointment shoing up before timing info like "appointment tomorrow"
	# for now, replace with apt
	newMsg = replace(newMsg, "appointment", "appt")

	# Fix 3 digit numbers with timing info like "520p"
	threeDigitsWithAP = re.search(r'\b(?P<time>\d{3}) ?(p|a|pm|am)\b', newMsg, re.IGNORECASE)
	if threeDigitsWithAP:
		oldtime = threeDigitsWithAP.group("time")  # This is the 520 part, the other is the 'p'
		newtime = oldtime[0] + ":" + oldtime[1:]

		newMsg = replace(newMsg, oldtime, newtime)

	# Fix 3 digit numbers with timing info like "at 520". Not that we don't have p/a but we require 'at'
	# We don't want to just swap in all 3 numbers tho, like $100
	# We also need to watch out for at 1230, so make sure its exactly 3 numbers
	threeDigitsWithAT = re.search(r'\bat (?P<time>\d{3})([^0-9]|\b)', newMsg, re.IGNORECASE)
	if threeDigitsWithAT:
		oldtime = threeDigitsWithAT.group("time")
		newtime = oldtime[0] + ":" + oldtime[1:]

		newMsg = replace(newMsg, oldtime, newtime)

	# Change '4th' to 'June 4th'
	dayOfMonth = re.search(r'\bthe (?P<time>(1st|2nd|3rd|[0-9]+th))', newMsg, re.IGNORECASE)
	if dayOfMonth:
		localtime = date_util.now(user.getTimezone())

		dayStr = dayOfMonth.group("time")
		number = int(filter(str.isdigit, str(dayStr)))

		if number < localtime.day:
			# They said 1st while it was June 2nd, so return July 1st
			monthName = (localtime + relativedelta.relativedelta(months=1)).strftime("%B")
		else:
			monthName = localtime.strftime("%B")

		# Turn 'the 9th' into 'June 9th'
		newMsg = replace(newMsg, "the %s" % dayStr, "%s %s" % (monthName, dayStr))

	# Take anything like 7ish and just make 7
	ish = re.search(r'\b(?P<time>[0-9]+)ish', newMsg, re.IGNORECASE)
	if ish:
		time = ish.group("time")
		newMsg = replace(newMsg, time + "ish", time)

	# Deal with "an hour"
	newMsg = replace(newMsg, r"\ban hour\b", "1 hour")


	# Take anything like 7 - 10 and turn into 7 to 10
	timeRange = re.search(r'(?P<match>[0-9](a|p|am|pm)? *- *[0-9])', newMsg, re.IGNORECASE)
	if timeRange:
		match = timeRange.group("match")
		newStr = replace(match, "-", " to ")
		newMsg = replace(newMsg, match, newStr)

	return newMsg


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

	return myResults


# Looks to see if the given time is the same hour and minute as now. Natty returns this if it doesn't
# know what else to do, like for queries of "today"
def isNattyDefaultTime(utcTime):
	now = date_util.now(pytz.utc)
	return utcTime.hour == now.hour and utcTime.minute == now.minute


def updatedTimeBasedOnUsedText(utcTime, usedText, timezone):
	if usedText.lower() == "next week":
		tzAwareDate = date_util.now(pytz.utc).astimezone(timezone)
		# This finds us the next Monday
		tzAwareDate = tzAwareDate + datetime.timedelta(days=-tzAwareDate.weekday(), weeks=1)
		tzAwareDate = tzAwareDate.replace(hour=9, minute=0)
		return tzAwareDate.astimezone(pytz.utc)
	return utcTime


def unixTime(dt):
	epoch = datetime.datetime.utcfromtimestamp(0).replace(tzinfo=pytz.utc)
	delta = dt - epoch
	return int(delta.total_seconds())

# This regex needs to tell us if the user typed in an intent for a certain time of day (am or pm)
amPmRegex = re.compile(r'(\d) ?(p|a|pm|am)\b|morning|evening|afternoon|night', re.IGNORECASE)


def isTomorrowInText(usedText):
	tmrPhrases = ["tomorrow", "tmr", "tommarow"]

	for phrase in tmrPhrases:
		if phrase in usedText.split(' '):
			return True
	return False


# Looks through time options and figures out which is best
# the phrase "for 1 hour" returns now and in an hour, so there use the second
# the phrase "5 and 8" returns at 5 and 8, so return the first
def getBestTimeFromChoices(choices):
	if len(choices) > 1:
		for choice in choices:
			dt = datetime.datetime.fromtimestamp(choice)
			if not isNattyDefaultTime(dt):
				return datetime.datetime.fromtimestamp(choice).replace(tzinfo=pytz.utc)
		return datetime.datetime.fromtimestamp(choices[0]).replace(tzinfo=pytz.utc)
	else:
		return datetime.datetime.fromtimestamp(choices[0]).replace(tzinfo=pytz.utc)


def processQuery(query, timezone):
	# get startDate from Natty
	nattyPort = "7990"
	# converting back to utf-8 for urllib
	nattyParams = {"q": unicode(query).encode('utf-8')}

	if timezone:
		nattyParams["tz"] = str(timezone)

	nattyParams["baseDate"] = unixTime(date_util.now(pytz.utc))

	nattyUrl = "http://localhost:%s/?%s" % (nattyPort, urllib.urlencode(nattyParams))

	logger.debug("Hitting natty url: %s" % nattyUrl)

	try:
		nattyResult = urllib2.urlopen(nattyUrl).read()
	except URLError as e:
		logger.error("Could not connect to Natty: %s" % (e.strerror))
		nattyResult = None

	result = list()

	if (nattyResult):
		nattyJson = json.loads(nattyResult)
		for entry in nattyJson:
			usedText = entry["matchingValue"]

			startDate = getBestTimeFromChoices(entry["timestamps"])

			# Correct for a few edgecases
			startDate = updatedTimeBasedOnUsedText(startDate, usedText, timezone)

			now = date_util.now(pytz.utc)
			tzAwareNow = date_util.now(timezone)

			# If its between midnight and 4 am local time and there's tomorrow in the phrase
			# Then move it back a day and do regular processing
			if tzAwareNow.hour >= 0 and tzAwareNow.hour < 4 and isTomorrowInText(usedText) and startDate > now:
				startDate = startDate - datetime.timedelta(days=1)

			# If we pulled out just an int less than 12, then pick the next time that time number happens.
			# So if its currently 14, and they say 8... then add
			if startDate < (now - datetime.timedelta(seconds=10)) and startDate > now - datetime.timedelta(hours=24):
				# If it has am or pm in the used text, then assume tomorrow
				if amPmRegex.search(usedText.lower()) is not None:
					startDate = startDate + datetime.timedelta(days=1)
				elif startDate > now - datetime.timedelta(hours=24) and startDate < now - datetime.timedelta(hours=12):
					# This is between 12 and 24 hours in the past, so:
					# Its 6pm, we say "3", natty returns "3am", we want to return 3am, so 24 hours
					startDate = startDate + datetime.timedelta(days=1)
				else:
					# Its 6pm, we say "8", natty returns "8am", we want to return 8pm, so 12 hours
					startDate = startDate + datetime.timedelta(hours=12)

			tzAwareStartDate = startDate.astimezone(timezone)
			# If we think tho that its super early in the morning and there's no am, we're probably wrong, so set it later
			if tzAwareStartDate.hour >= 0 and tzAwareStartDate.hour < 6 and "am" not in usedText.lower():
				startDate = startDate + datetime.timedelta(hours=12)

			column = entry["column"]
			newQuery = getNewQuery(query, usedText, column)

			# They said a specific date but its in the past...so it needs to be bumped by a year
			if "EXPLICIT_DATE" in entry["syntaxTree"] and startDate < now:
				startDate = startDate + relativedelta.relativedelta(years=1)  # Must use relativedelta due to leapyears

			# RELATIVE_DATE  shows up for in 2 days, or Wed
			# EXPLICIT_DATE  shows up for July 1
			# RELATIVE_TIME  shows up for "in an hour" so hasDate should be true (since its today)
			# tonight        is a hack
			hasDate = "RELATIVE_DATE" in entry["syntaxTree"] or "EXPLICIT_DATE" in entry["syntaxTree"] or "RELATIVE_TIME" in entry["syntaxTree"] or "tonight" in usedText.lower()

			hasTime = "EXPLICIT_TIME" in entry["syntaxTree"] or not isNattyDefaultTime(startDate)
			result.append(NattyResult(startDate, newQuery, usedText, hasDate, hasTime))

			"""


			hasDate = "RELATIVE_DATE" in entry["syntaxTree"] or "EXPLICIT_DATE" in entry["syntaxTree"] or "RELATIVE_TIME" in entry["syntaxTree"]

			hasTime = "EXPLICIT_TIME" in entry["syntaxTree"] or "RELATIVE_TIME" in entry["syntaxTree"]
			result.append(NattyResult(startDate, newQuery, usedText, hasDate, hasTime))

			"""
	return result


def representsInt(s):
	try:
		int(s)
		return True
	except ValueError:
		return False


# This method takes the query and usedText and returns back the query without the usedText in it
# The column is where the phrase starts if its defined
def getNewQuery(query, usedText, column=None):
	if column:
		newQuery = query[:column - 1] + query[column - 1 + len(usedText):]
	else:
		newQuery = query.replace(usedText, '')
	newQuery = newQuery.replace('  ', ' ').strip()

	return newQuery

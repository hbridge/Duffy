import datetime
import json
import re

from dateutil import relativedelta
from peanut.settings import constants
import pytz
from smskeeper import analytics
from common import date_util
from smskeeper import keeper_constants
from smskeeper import msg_util
from common import natty_util
from smskeeper.models import Entry, Contact
from smskeeper import helper_util, sms_util, entry_util

import logging
logger = logging.getLogger(__name__)



def getLastActionTime(user):
	if user.getStateData(keeper_constants.LAST_ACTION_KEY):
		return datetime.datetime.utcfromtimestamp(user.getStateData(keeper_constants.LAST_ACTION_KEY)).replace(tzinfo=pytz.utc)
	else:
		return None


# Returns true if thislook slike a snooze command
# If we find "again" or "snooze"
# or if the cleaned Text is blank
def isSnoozeForEntry(user, msg, entry, nattyResult):
	query = msg.lower()
	if nattyResult.validTime():
		cleanedText = msg_util.cleanedReminder(nattyResult.queryWithoutTiming)
		interestingWords = msg_util.getInterestingWords(cleanedText)

		if len(interestingWords) > 0:
			bestEntry, score = entry_util.getBestEntryMatch(user, ' '.join(interestingWords))
			if bestEntry and bestEntry.id != entry.id and score > 60:
				return False

		if "again" in query or "snooze" in query:
			logger.info("User %s: I think this is a snooze bc we found 'again' or 'snooze'" % (user.id))
			return True
		elif len(interestingWords) == 0:
			logger.info("User %s: I think this is a snooze bc there's no interesting words" % (user.id))
			return True

	return False


# Returns True if this message has a valid time and it doesn't look like another remind command
# If reminderSent is true, then we look for again or snooze which if found, we'll assume is a followup
# Like "remind me again in 5 minutes"
# If the message (without timing info) only is "remind me" then also is a followup due to "remind me in 5 minutes"
# Otherwise False
def isFollowup(user, entry, msg, nattyResult):
	now = date_util.now(pytz.utc)

	if not entry:
		return False

	if nattyResult.validTime():
		cleanedText = msg_util.cleanedReminder(nattyResult.queryWithoutTiming)  # no "Remind me"
		lastActionTime = getLastActionTime(user)
		interestingWords = msg_util.getInterestingWords(cleanedText)
		isRecentAction = True if (lastActionTime and (now - lastActionTime) < datetime.timedelta(minutes=5)) else False

		# Covers cases where there the cleanedText is "in" or "around"
		if len(cleanedText) <= 2:
			logger.info("User %s: I think this is a followup to %s bc its less than 2 letters" % (user.id, entry.id))
			return True
		# If they write "no, remind me sunday instead" then want to process as followup
		elif msg_util.startsWithNo(nattyResult.queryWithoutTiming):
			logger.info("User %s: I think this is a followup to %s bc it starts with a No" % (user.id, entry.id))
			return True
		elif isSnoozeForEntry(user, msg, entry, nattyResult):
			logger.info("User %s: I think this is a followup to %s bc its a snooze" % (user.id, entry.id))
			return True
		# If we were just editing this entry and the query has nearly no interesting words
		# unless it's a snooze command, in which case it may refer to a different entry
		elif isRecentAction and len(interestingWords) < 2 and not msg_util.isSnoozeCommand(nattyResult.queryWithoutTiming):
			logger.info("User %s: I think this is a followup to %s bc we updated it recently and no interesting words" % (user.id, entry.id))
			return True
		else:
			bestEntry, score = entry_util.getBestEntryMatch(user, nattyResult.queryWithoutTiming)
			# This could be a new entry due to todos
			# Check to see if there's a fuzzy match to the last entry.  If so, treat as followup
			if score > 60 and bestEntry and bestEntry.id == entry.id:
				if isRecentAction:
					logger.info("User %s: I think '%s' is a followup because it matched entry id %s with score %s" % (user.id, nattyResult.queryWithoutTiming, bestEntry.id, score))
					return True
				else:
					logger.info("User %s: I think '%s' looks like a followup because it matched entry id %s with score %s but it wasn't recent so not thinking as such" % (user.id, nattyResult.queryWithoutTiming, bestEntry.id, score))

	return False


def createReminderEntry(user, nattyResult, msg, sendFollowup, keeperNumber):
	cleanedText = msg_util.cleanedReminder(nattyResult.queryWithoutTiming)  # no "Remind me"
	cleanedText = msg_util.warpReminderText(cleanedText)  # I to your
	entry = Entry.createEntry(user, keeperNumber, keeper_constants.REMIND_LABEL, cleanedText)

	# If our entry has timing information in it, then mark it for manual checking
	# This helps for things like "remind me thursday about pooping at 6pm"
	# TODO(Derek): Once we're confident, put a check in here:
	# tempResult = getNattyResult(user, cleanedText)
	# if not(validTime(tempResult):
	entry.manually_check = True

	# If the entry had no time or date information, mark it as default
	if not nattyResult.hadTime and not nattyResult.hadDate:
		entry.is_default_time_and_date = True

	entry.remind_timestamp = nattyResult.utcTime

	entry.orig_text = json.dumps([msg])
	entry.save()

	logger.info("User %s: Created entry %s and msg '%s' with timestamp %s from using nattyResult %s" % (user.id, entry.id, msg, nattyResult.utcTime, nattyResult))

	suspiciousHour = dealWithSuspiciousHour(user, entry, keeperNumber)

	analytics.logUserEvent(
		user,
		"Created Reminder",
		{
			"Needed Followup": sendFollowup,
			"Was Suspicious Hour": suspiciousHour,
			"In tutorial": not user.isTutorialComplete(),
			"Is shared": len(entry.users.all()) > 1,
			"interface": keeperNumber,
		}
	)

	return entry


def dealWithSuspiciousHour(user, entry, keeperNumber):
	# If we're setting for early morning, send out a warning
	tzAwareDate = entry.remind_timestamp.astimezone(user.getTimezone())
	hourForUser = tzAwareDate.hour
	if (isReminderHourSuspicious(hourForUser) and keeperNumber != constants.SMSKEEPER_TEST_NUM):
		logger.info("User %s: Scheduling an alert for %s am local time, might want to check entry id %s" % (user.id, hourForUser, entry.id))
		return True
	return False


def isReminderHourSuspicious(hourForUser):
	return hourForUser >= 0 and hourForUser <= 6


def updateReminderEntry(user, nattyResult, msg, entry, keeperNumber, isSnooze=False):
	newDate = entry.remind_timestamp.astimezone(user.getTimezone())
	nattyTzTime = nattyResult.utcTime.astimezone(user.getTimezone())

	# Edgecase: If the original entry had no time or date info and the nattyresult
	# does have a time, then assume the date will be correct as well (should be today)
	if entry.is_default_time_and_date and nattyResult.hadTime and not nattyResult.hadDate:
		entry.is_default_time_and_date = False
		newDate = newDate.replace(year=nattyTzTime.year)
		newDate = newDate.replace(month=nattyTzTime.month)
		newDate = newDate.replace(day=nattyTzTime.day)

	# Only update with a date or time if Natty found one
	if nattyResult.hadDate:
		newDate = newDate.replace(year=nattyTzTime.year)
		newDate = newDate.replace(month=nattyTzTime.month)
		newDate = newDate.replace(day=nattyTzTime.day)

	if nattyResult.hadTime:
		newDate = newDate.replace(hour=nattyTzTime.hour)
		newDate = newDate.replace(minute=nattyTzTime.minute)
		newDate = newDate.replace(second=nattyTzTime.second)

	logger.info("User %s: Updating entry %s with and msg '%s' with timestamp %s from using nattyResult %s.  Old timestamp was %s" % (user.id, entry.id, msg, newDate, nattyResult, entry.remind_timestamp))
	entry.remind_timestamp = newDate.astimezone(pytz.utc)
	entry.remind_to_be_sent = True

	entry.manually_check = True
	entry.hidden = False

	if entry.orig_text:
		try:
			origTextList = json.loads(entry.orig_text)
		except ValueError:
			origTextList = [entry.orig_text]
	else:
		origTextList = []
	origTextList.append(msg)
	entry.orig_text = json.dumps(origTextList)
	entry.save()

	suspiciousHour = dealWithSuspiciousHour(user, entry, keeperNumber)

	analytics.logUserEvent(
		user,
		"Updated Reminder",
		{
			"Was Suspicious Hour": suspiciousHour,
			"In tutorial": not user.isTutorialComplete(),
			"Is shared": len(entry.users.all()) > 1,
			"Type": "Snooze" if isSnooze else "Time Correction"
		}
	)


def getDefaultTime(user, isToday=False):
	userNow = date_util.now(user.getTimezone())

	if isToday:
		# If before 2 pm, remind at 6 pm
		if userNow.hour < 14:
			replaceTime = userNow.replace(hour=18, minute=0, second=0)
		# If between 2 pm and 5 pm, remind at 9 pm
		elif userNow.hour >= 14 and userNow.hour < 17:
			replaceTime = userNow.replace(hour=21, minute=0, second=0)
		else:
			# If after 5 pm, remind 9 am next day
			replaceTime = userNow + datetime.timedelta(days=1)
			replaceTime = replaceTime.replace(hour=9, minute=0, second=0)
	else:
		# Remind 9 am next day
		replaceTime = userNow + datetime.timedelta(days=1)
		replaceTime = replaceTime.replace(hour=9, minute=0, second=0)
	return replaceTime


#  Send off a response like "I'll remind you Sunday at 9am" or "I'll remind mom Sunday at 9am"
def sendCompletionResponse(user, entry, sendFollowup, keeperNumber):
	tzAwareDate = entry.remind_timestamp.astimezone(user.getTimezone())

	# Include time if old product or if its not a default time
	includeTime = not user.isDigestTime(entry.remind_timestamp)

	# Get the text liked "tomorrow" or "Sat at 5pm"
	userMsg = msg_util.naturalize(date_util.now(user.getTimezone()), tzAwareDate, includeTime=includeTime)

	# If this is a shared reminder then look up the handle to send things out with
	if user == entry.creator and len(entry.users.all()) > 1:
		for target in entry.users.all():
			if target.id != user.id:
				contact = Contact.fetchByTarget(user, target)
				handle = contact.handle
	else:
		handle = "you"

	toSend = "%s I'll remind %s %s." % (helper_util.randomAcknowledgement(), handle, userMsg)

	# Tutorial gets a special followup message
	if sendFollowup:
		if not user.isTutorialComplete():
			toSend = toSend + " (If that time doesn't work, just tell me what time is better)"
		else:
			toSend = toSend + "\n\n"
			toSend = toSend + "If that time doesn't work, tell me what time is better"

	sms_util.sendMsg(user, toSend, None, keeperNumber)


# If we got a natty result with no time, then we need to pick one.
# If there was no date, pick the default time (could be 9am tmr or later today)
# If there a date, then see if its today.  If so, pick best default time for today.
# If not today, then pick that day and set to the default time (9am)
def dealWithDefaultTime(user, nattyResult):
	if nattyResult.hadTime:
		return nattyResult

	# If there was no date whatsoever, plug in the default time
	if not nattyResult.hadDate:
		nattyResult.utcTime = getDefaultTime(user)
	else:
		tzAwareNow = date_util.now(user.getTimezone())
		tzAwareDate = nattyResult.utcTime.astimezone(user.getTimezone())

		# If the user says 'today', then this should match up.
		if tzAwareDate.day == tzAwareNow.day:
			nattyResult.utcTime = getDefaultTime(user, isToday=True)

			# We set this to say we had a date so we swap in the time correctly if its a followup
			nattyResult.hadTime = True
		else:
			tzAwareDate = tzAwareDate.replace(hour=9, minute=0)
			nattyResult.utcTime = tzAwareDate.astimezone(pytz.utc)

	return nattyResult


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
		"for": "",  # For an hour
		"by": "at"}

	for word, replaceWith in words.iteritems():
		search = re.search(r'\b(?P<phrase>%s [0-9]+)' % word, newMsg, re.IGNORECASE)

		if search:
			phrase = search.group("phrase")
			newPhrase = replace(phrase, word, replaceWith).strip()
			newMsg = replace(newMsg, phrase, newPhrase)

	# Remove o'clock
	newMsg = replace(newMsg, "o'clock", "")
	newMsg = replace(newMsg, "oclock", "")

	# Fix "again at 3" situation where natty doesn't like that...wtf
	againAt = re.search(r'.*again at ([0-9])', newMsg, re.IGNORECASE)
	if againAt:
		newMsg = replace(newMsg, "again at", "at")

	# Fix 3 digit numbers with timing info like "520p"
	threeDigitsWithAP = re.search(r'.* (?P<time>\d{3}) ?(p|a|pm|am)\b', newMsg, re.IGNORECASE)
	if threeDigitsWithAP:
		oldtime = threeDigitsWithAP.group("time")  # This is the 520 part, the other is the 'p'
		newtime = oldtime[0] + ":" + oldtime[1:]

		newMsg = replace(newMsg, oldtime, newtime)

	# Fix 3 digit numbers with timing info like "at 520". Not that we don't have p/a but we require 'at'
	threeDigitsWithAT = re.search(r'.*at (?P<time>\d{3})', newMsg, re.IGNORECASE)
	if threeDigitsWithAT:
		oldtime = threeDigitsWithAT.group("time")
		newtime = oldtime[0] + ":" + oldtime[1:]

		newMsg = replace(newMsg, oldtime, newtime)

	# Change '4th' to 'June 4th'
	dayOfMonth = re.search(r'.*the (?P<time>(1st|2nd|3rd|[0-9]+th))', newMsg, re.IGNORECASE)
	if dayOfMonth:
		localtime = date_util.now(user.getTimezone())

		dayStr = dayOfMonth.group("time")
		number = int(filter(str.isdigit, str(dayStr)))

		if number <= localtime.day:
			# They said 1st while it was June 2nd, so return July 1st
			monthName = (localtime + relativedelta.relativedelta(months=1)).strftime("%B")
		else:
			monthName = localtime.strftime("%B")

		# Turn 'the 9th' into 'June 9th'
		newMsg = replace(newMsg, "the %s" % dayStr, "%s %s" % (monthName, dayStr))

	# Take anything like 7ish and just make 7
	ish = re.search(r'.* (?P<time>[0-9]+)ish', newMsg, re.IGNORECASE)
	if ish:
		time = ish.group("time")
		newMsg = replace(newMsg, time + "ish", time)

	# Deal with "an hour"
	newMsg = replace(newMsg, r"\ban hour\b", "1 hour")

	return newMsg


def getBestNattyResult(nattyResults):
	if len(nattyResults) == 0:
		return None

	now = date_util.now(pytz.utc)

	nattyResults = filter(lambda x: x.utcTime >= now - datetime.timedelta(seconds=10), nattyResults)

	# Sort by the date, we want to soonest first
	nattyResults = sorted(nattyResults, key=lambda x: x.utcTime)

	# Sort by if there was a time in the date or not
	nattyResults = sorted(nattyResults, key=lambda x: 0 if x.hadTime else 1)

	# prefer anything that has "at" in the text
	# Make sure it's "at " (with a space) since Saturday will match
	nattyResults = sorted(nattyResults, key=lambda x: "at " in x.textUsed, reverse=True)

	# Filter out stuff that was only using term "now"
	nattyResults = filter(lambda x: x.textUsed.lower() != "now", nattyResults)

	if len(nattyResults) == 0:
		return None

	return nattyResults[0]


def getNattyResult(user, msg):
	msgCopy = msg

	# Deal with legacy stuff
	if '#remind' in msgCopy:
		msgCopy = msgCopy.replace("#reminder", "remind me")
		msgCopy = msgCopy.replace("#remind", "remind me")

	nattyMsg = fixMsgForNatty(msgCopy, user)
	nattyResult = getBestNattyResult(natty_util.getNattyInfo(nattyMsg, user.getTimezone()))

	if not nattyResult:
		nattyResult = natty_util.NattyResult(None, msgCopy, None, False, False)

	# Deal with situation where a time wasn't specified
	if not nattyResult.hadTime:
		nattyResult = dealWithDefaultTime(user, nattyResult)

	return nattyResult


"""
Temp remove due to pausing shared reminders
# Don't do any of this logic in the tutorial state, shouldn't be correct
if not isTutorial(user):
	handle = msg_util.getReminderHandle(nattyResult.queryWithoutTiming)  # Grab "me" or "mom"

	if handle and handle != "me":
		# If we ever handle multiple handles... we need to create seperate entries to deal with snoozes
		contact = Contact.fetchByHandle(user, handle)

		if contact is None:
			logger.info("User %s: Didn't find handle %s and msg %s on entry %s" % (user.id, handle, msg, entry.id))
			# We couldn't find the handle so go into unresolved state
			# Set data for ourselves for when we come back
			user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entry.id)
			user.setStateData("fromUnresolvedHandles", True)
			user.setState(keeper_constants.STATE_UNRESOLVED_HANDLES, saveCurrent=True)
			user.setStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY, [handle])
			user.save()
			return False
		else:
			logger.info("User %s: Didn't find handle %s and entry %s...goint to unresolved" % (user.id, handle, entry.id))
			# We found the handle, so share the entry with the user.
			entry.users.add(contact.target)
"""
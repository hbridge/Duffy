import datetime
import json
import random

from peanut.settings import constants
import pytz
from smskeeper import analytics
from common import date_util
from smskeeper import keeper_constants, keeper_strings
from smskeeper import msg_util
from common import natty_util
from smskeeper.models import Entry, Contact
from smskeeper import helper_util, sms_util, entry_util
import django
from smskeeper import tips

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
		elif isRecentAction and len(interestingWords) < 2:
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


def createReminderEntry(user, nattyResult, msg, followups, keeperNumber, recurrence=None):
	cleanedText = msg_util.cleanedReminder(nattyResult.queryWithoutTiming, recurrence)  # no "Remind me", or recurrence text
	cleanedText = msg_util.warpReminderText(cleanedText)  # I to your
	entry = Entry.createEntry(user, keeperNumber, keeper_constants.REMIND_LABEL, cleanedText)

	# If our entry has timing information in it, then mark it for manual checking
	# This helps for things like "remind me thursday about pooping at 6pm"
	# TODO(Derek): Once we're confident, put a check in here:
	# tempResult = getNattyResult(user, cleanedText)
	# if not(validTime(tempResult):
	if not keeper_constants.isAdminInterface(keeperNumber):
		entry.manually_check = True

	# If the entry had no time or date information, mark it as default
	if not nattyResult.hadTime:
		entry.use_digest_time = True

		tzAwareDate = nattyResult.utcTime.astimezone(user.getTimezone())
		tzAwareDate.replace(hour=user.digest_hour, minute=user.digest_minute)
		entry.remind_timestamp = tzAwareDate.astimezone(pytz.utc)
	else:
		entry.remind_timestamp = nattyResult.utcTime

	entry.orig_text = json.dumps([msg])
	if recurrence is not None:
		entry.remind_recur = recurrence
	entry.save()

	logger.info("User %s: Created entry %s and msg '%s' with timestamp %s from using nattyResult %s" % (user.id, entry.id, msg, nattyResult.utcTime, nattyResult))

	suspiciousHour = dealWithSuspiciousHour(user, entry, keeperNumber)

	NumUsers = 1
	analytics.logUserEvent(
		user,
		"Created Reminder",
		{
			"Needed Followup": (len(followups) > 0),
			"Was Suspicious Hour": suspiciousHour,
			"In tutorial": not user.isTutorialComplete(),
			"Is shared": (NumUsers > 1),
			"interface": keeperNumber,
		}
	)

	return entry


def hasBeforePhrase(entry):
	keywords = ["test", "report", "hw", "assignment", "assn", "homework", "essay", "paper", "exam"]

	hasKeyword = False
	for keyword in keywords:
		if keyword in entry.text:
			hasKeyword = True

	if "due" in entry.text and hasKeyword:
		pass


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
	userNow = date_util.now(user.getTimezone())

	# Edgecase: If the original entry had no time or date info and the nattyresult
	# does have a time, then assume the date will be correct as well (should be today)
	if entry.use_digest_time and nattyResult.hadTime and not nattyResult.hadDate:
		entry.use_digest_time = False
		newDate.replace(year=nattyTzTime.year)
		newDate = newDate.replace(year=nattyTzTime.year, month=nattyTzTime.month, day=nattyTzTime.day)

	# Only update with a date or time if Natty found one
	# Or if its a snooze. Snoozes are relative to user's now so its ok to swap everything out
	if nattyResult.hadDate or isSnooze:
		newDate = newDate.replace(year=nattyTzTime.year, month=nattyTzTime.month, day=nattyTzTime.day)

	if nattyResult.hadTime or isSnooze:
		# Make sure we set the correct digest time if there's no time defined
		if not nattyResult.hadTime:
			entry.use_digest_time = True
			newDate = newDate.replace(hour=user.digest_hour)
			newDate = newDate.replace(minute=user.digest_minute)
			newDate = newDate.replace(second=0)
		else:
			entry.use_digest_time = False
			newDate = newDate.replace(hour=nattyTzTime.hour)
			newDate = newDate.replace(minute=nattyTzTime.minute)
			newDate = newDate.replace(second=nattyTzTime.second)

	# Edgecase: Original reminder was for 5pm, user says 'remind me 7am', but we have no date so replace in
	# When this happens, use natty's date as it'll be the default (probably tomorrow)
	# Normally, isSnooze should be True, but we can't rely upon that.
	if newDate < userNow:
		if not nattyResult.hadDate:
			newDate = newDate.replace(year=nattyTzTime.year, month=nattyTzTime.month, day=nattyTzTime.day)
		else:
			# Something really went wrong
			logger.error("User %s: Setting entry %s to an incorrect time in the past.  old %s  and new  %s   nattyResult: %s" % (user.id, entry.id, entry.remind_timestamp, newDate, nattyResult))

	logger.info("User %s: Updating entry %s with and msg '%s' with timestamp %s from using nattyResult %s.  Old timestamp was %s" % (user.id, entry.id, msg, newDate, nattyResult, entry.remind_timestamp))
	# since we may be using useDigestTime=True, need to call the custom setter
	entry.setRemindTime(newDate.astimezone(pytz.utc), useDigestTime=entry.use_digest_time)
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


#  Send off a response like "I'll remind you Sunday at 9am" or "I'll remind mom Sunday at 9am"
def sendCompletionResponse(user, entry, followups, keeperNumber):
	logger.info("Send completion response with followups %s", followups)
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
				handle = contact.displayName()
	else:
		handle = "you"

	toSend = "%s I'll remind %s %s." % (helper_util.randomAcknowledgement(), handle, userMsg)

	responseClassification = None
	# time followups
	if keeper_constants.FOLLOWUP_TIME in followups:
		if not user.isTutorialComplete():
			toSend = toSend + " (If that time doesn't work, just tell me what time is better.)"
		else:
			toSend = toSend + " " + random.choice(keeper_strings.FOLLOWUP_TIME_TEXT)

	# sharing followups
	if user.isTutorialComplete():
		if keeper_constants.FOLLOWUP_SHARE_UNRESOLVED in followups:
			toSend = toSend + "\n" + keeper_strings.FOLLOWUP_SHARE_UNRESOLVED_TEXT
			responseClassification = keeper_constants.OUTGOING_SHARE_PROMPT
		elif keeper_constants.FOLLOWUP_SHARE_RESOLVED in followups:
			toSend = toSend + "\n" + keeper_strings.FOLLOWUP_SHARE_RESOLVED_TEXT

	sms_util.sendMsg(user, toSend, None, keeperNumber, classification=responseClassification)


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
			replaceTime = userNow.replace(hour=23, minute=0, second=0)
	else:
		# Remind 9 am next day
		replaceTime = userNow + datetime.timedelta(days=1)
		replaceTime = replaceTime.replace(hour=9, minute=0, second=0)
	return replaceTime


# If we got a natty result with no time, then we need to pick one.
# If there was no date, pick the default time (could be 9am tmr or later today)
# If there a date, then see if its today.  If so, pick best default time for today.
# If not today, then pick that day and set to the default time (9am)
def fillInWithDefaultTime(user, nattyResult):
	if nattyResult.hadTime:
		return nattyResult

	# If there was no date whatsoever, plug in the default time
	if not nattyResult.hadDate:
		nattyResult.utcTime = getDefaultTime(user)
	else:
		tzAwareNow = date_util.now(user.getTimezone())
		tzAwareDate = nattyResult.utcTime.astimezone(user.getTimezone())

		# If the user says 'today', then this should match up.
		if tzAwareDate.day == tzAwareNow.day and "today" in nattyResult.textUsed.lower():
			nattyResult.utcTime = getDefaultTime(user, isToday=True)

			# We set this to say we had a date so we swap in the time correctly if its a followup
			nattyResult.hadTime = True
		else:
			tzAwareDate = tzAwareDate.replace(hour=9, minute=0)
			nattyResult.utcTime = tzAwareDate.astimezone(pytz.utc)

	return nattyResult


def getDefaultNattyResult(msg, user):
	nattyResult = natty_util.NattyResult(None, msg, None, False, False)
	return fillInWithDefaultTime(user, nattyResult)


# TODO(Derek): To be deleted
def getNattyResult(user, msg):
	msgCopy = msg

	# Deal with legacy stuff
	# Doesn't really belong here
	if '#remind' in msgCopy:
		msgCopy = msgCopy.replace("#reminder", "remind me")
		msgCopy = msgCopy.replace("#remind", "remind me")

	nattyResult = natty_util.getNattyResult(msgCopy, user)

	if not nattyResult:
		nattyResult = natty_util.NattyResult(None, msgCopy, None, False, False)

	# Deal with situation where a time wasn't specified
	if not nattyResult.hadTime:
		nattyResult = fillInWithDefaultTime(user, nattyResult)

	return nattyResult


def shareReminders(user, entries, handles, keeperNumber):
	sharedHandles = list()
	notFoundHandles = list()
	nonActivatedRecipients = False
	if not isinstance(entries, django.db.models.query.QuerySet) and not isinstance(entries, list):
		raise TypeError("entries must be list or django.db.models.query.QuerySet, actual type: %s" % (type(entries)))
	if not isinstance(handles, list):
		raise TypeError("handles must be a list, actual type: %s" % (type(handles)))
	for handle in handles:
		contact = Contact.fetchByHandle(user, handle)
		if contact is None:
			notFoundHandles.append(handle)
		else:
			# add the target user to the entry and send them a message
			sharedHandles.append(handle)
			for entry in entries:
				logger.info("sharing entry with text: %s orig_text: %s", entry.text, entry.orig_text)
				entry.users.add(contact.target)
				entry.remind_recur = keeper_constants.RECUR_ONE_TIME
				entry.text = getSharedEntryText(entry, user, handles)
				entry.save()

			shareText = None

			# if the user isn't activated send them special text
			introText = "Hi there :wave: "
			if not contact.target.activated:
				introText += "%s " % keeper_strings.SHARED_REMINDER_RECIPIENT_INTRO.replace(":NAME:", user.nameOrPhone())
				nonActivatedRecipients = True

			if len(entries) == 1:
				tzAwareDate = entry.remind_timestamp.astimezone(user.getTimezone())
				shareText = "%sJust a heads up that %s set a reminder for you %s, so I'll follow up with you then." % (
					introText,
					user.nameOrPhone(),
					msg_util.naturalize(date_util.now(user.getTimezone()), tzAwareDate, includeTime=True),
				)
			else:
				shareText = "%s%s set %d reminders for you." % (
					introText,
					user.nameOrPhone(),
					len(entries)
				)
			sms_util.sendMsg(contact.target, shareText, None, contact.target.getKeeperNumber())
			if len(contact.target.getMessages(incoming=False)) == 0:
				# this is a new user, send them special text.
				sms_util.sendDelayedMsg(
					contact.target,
					keeper_strings.SHARED_REMINDER_RECIPIENT_UPSELL,
					10,
					contact.target.getKeeperNumber()
				)

	analytics.logUserEvent(
		user,
		"Shared Reminder",
		{
			"Num Users": len(handles),
			"Num Entries:": len(entries),
			"Targets Unactivated": nonActivatedRecipients,
		}
	)

	return sharedHandles, notFoundHandles


def getSharedEntryText(entry, user, handles):
	originalText = json.loads(entry.orig_text)[-1]
	nattyResult = natty_util.getNattyResult(originalText, user)
	text = nattyResult.queryWithoutTiming if nattyResult else originalText
	return msg_util.cleanedReminder(text, recurrence=None, shareHandles=handles)

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
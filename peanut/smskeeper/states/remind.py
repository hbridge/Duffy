import datetime
import pytz
import logging
import re
import json

from peanut.settings import constants

from common import natty_util

from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants
from smskeeper import helper_util
from smskeeper import analytics

from smskeeper.models import Entry, Contact

logger = logging.getLogger(__name__)


# Might need to move these to common constants file at some point.
FROM_TUTORIAL_KEY = "fromtutorial"


# Returns True if the time exists and isn't within 10 seconds of now.
# We check for the 10 seconds to deal with natty phrases that don't really tell us a time (like "today")
def validTime(startDate):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	return not (startDate is None or abs((now - startDate).total_seconds()) < 10)


def isNattyDefaultTime(startDate):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	return startDate.hour == now.hour and startDate.minute == now.minute


# Returns True if this message has a valid time and it doesn't look like another remind command
# If reminderSent is true, then we look for again or snooze which if found, we'll assume is a followup
# Like "remind me again in 5 minutes"
# If the message (without timing info) only is "remind me" then also is a followup due to "remind me in 5 minutes"
# Otherwise False
def isFollowup(startDate, queryWithoutTiming, reminderSent):
	if validTime(startDate):
		cleanedText = msg_util.cleanedReminder(queryWithoutTiming)  # no "Remind me"
		if reminderSent and msg_util.isRemindCommand(queryWithoutTiming):
			if "again" in queryWithoutTiming.lower() or "snooze" in queryWithoutTiming.lower():
				return True
			else:
				return False
		# Covers cases where there is a followup like "remind me in 5 minutes"
		elif len(cleanedText) <= 2 or cleanedText == "around":
			return True
		elif not msg_util.isRemindCommand(queryWithoutTiming):
			return True
	return False


def isTutorial(user):
	return False if user.getStateData(FROM_TUTORIAL_KEY) is None else True


def dealWithTutorialEdgecases(user, msg, keeperNumber):
	# If we're coming from the tutorial and we find a message with a zipcode in it...just ignore the whole message
	# Would be great not to have a hack here
	if user.getStateData(FROM_TUTORIAL_KEY):
		postalCodes = re.search(r'.*(\d{5}(\-\d{4})?)', msg)
		if postalCodes:
			sms_util.sendMsg(user, u"Got it.", None, keeperNumber)
			return True
	return False


# If we got back a "natty default" time, which is the same time as now but a few days in the future
# default it to 9 am the local time
# Pass in startDate here since its in UTC, same as our server
def dealWithDefaultTime(user, startDate):
	if startDate:
		tzAwareDate = startDate.astimezone(user.getTimezone())
		if isNattyDefaultTime(startDate):
			tzAwareDate = tzAwareDate.replace(hour=9, minute=0)
			startDate = tzAwareDate.astimezone(pytz.utc)

	return startDate


def process(user, msg, requestDict, keeperNumber):
	if dealWithTutorialEdgecases(user, msg, keeperNumber):
		return True

	# Deal with legacy stuff
	if '#remind' in msg:
		msg = msg.replace("#reminder", "remind me")
		msg = msg.replace("#remind", "remind me")

	nattyResults = natty_util.getNattyInfo(msg, user.getTimezone())

	if len(nattyResults) > 0:
		startDate, queryWithoutTiming, usedText = nattyResults[0]
	else:
		startDate = None
		queryWithoutTiming = msg

	# Change time to 9am if he user wasn't specific
	startDate = dealWithDefaultTime(user, startDate)

	# Create a new reminder
	if not user.getStateData("entryId"):
		sendFollowup = False
		if not validTime(startDate):
			startDate = getDefaultTime(user)
			sendFollowup = True

		entry = createReminderEntry(user, startDate, msg, queryWithoutTiming, sendFollowup, keeperNumber)

		# See if the entry didn't create. This means there's unresolved handes
		if not entry:
			return False

		sendCompletionResponse(user, entry, sendFollowup, keeperNumber)

		# If we came from the tutorial, then set state and return False so we go back for reprocessing
		if user.getStateData(FROM_TUTORIAL_KEY):
			# Note, some behind the scene magic sets the state and state_data for us.  So this call
			# is kind of overwritten.  Done so the tutorial state can worry about its state and formatting
			user.setState(keeper_constants.STATE_TUTORIAL_REMIND)
			user.save()
			return False

		# Always save the entryId state since we always come back into this state.
		# If they don't enter timing info then we kick out
		user.setStateData("entryId", entry.id)
		user.save()
	else:
		# If we have an entry id, then that means we are doing a follow up
		# See if what they entered is a valid time and if so, assign it.
		# If not, kick out to normal mode and re-process
		entryId = int(user.getStateData("entryId"))
		entry = Entry.objects.get(id=entryId)

		if user.getStateData("fromUnresolvedHandles"):
			logger.debug("Going to deal with unresolved handles for entry %s" % entry.id)

			# Mark it that we're not coming back from unresolved handle
			# So incase there's a followup we don't, re-enter this section
			user.setStateData("fromUnresolvedHandles", False)
			user.save()

			unresolvedHandles = user.getStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY)
			# See if we have all the handles resolved
			if len(unresolvedHandles) == 0:
				for handle in user.getStateData(keeper_constants.RESOLVED_HANDLES_DATA_KEY):
					contact = Contact.fetchByHandle(user, handle)
					entry.users.add(contact.target)

				sendCompletionResponse(user, entry, False, keeperNumber)

			else:
				# This message could be a correction or something else.  Might need more logic here
				sendCompletionResponse(user, entry, False, keeperNumber)

		elif isFollowup(startDate, queryWithoutTiming, user.getStateData("reminderSent")):
			logger.debug("Doing followup on entry %s with msg %s" % (entry.id, msg))
			updateReminderEntry(user, startDate, msg, entry, keeperNumber)
			sendCompletionResponse(user, entry, False, keeperNumber)

			# This means it was a snooze
			if user.getStateData("reminderSent"):
				entry.hidden = False
				entry.save()
			return True
		else:
			# Send back for reprocessing
			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
			return False

	return True


def dealWithSuspiciousHour(user, utcDate, entry, keeperNumber):
	# If we're setting for early morning, send out a warning
	tzAwareDate = utcDate.astimezone(user.getTimezone())
	hourForUser = tzAwareDate.hour
	if (isReminderHourSuspicious(hourForUser) and keeperNumber != constants.SMSKEEPER_TEST_NUM):
		logger.error("Scheduling an alert for %s am local time for user %s, might want to check entry id %s" % (hourForUser, user.id, entry.id))
		return True
	return False


def createReminderEntry(user, utcDate, msg, queryWithoutTiming, sendFollowup, keeperNumber):
	cleanedText = msg_util.cleanedReminder(queryWithoutTiming)  # no "Remind me"
	entry = Entry.createEntry(user, keeperNumber, keeper_constants.REMIND_LABEL, cleanedText)

	entry.remind_timestamp = utcDate
	entry.orig_text = json.dumps([msg])
	entry.save()

	handle = msg_util.getReminderHandle(queryWithoutTiming)  # Grab "me" or "mom"

	if handle != "me":
		contact = Contact.fetchByHandle(user, handle)

		if contact is None:
			logger.debug("Didn't find handle %s for user %s and msg %s on entry %s" % (handle, user.id, msg, entry.id))
			# We couldn't find the handle so go into unresolved state
			# Set data for ourselves for when we come back
			user.setStateData("entryId", entry.id)
			user.setStateData("fromUnresolvedHandles", True)
			user.setState(keeper_constants.STATE_UNRESOLVED_HANDLES, saveCurrent=True)
			user.setStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY, [handle])
			user.save()
			return False
		else:
			logger.debug("Didn't find handle %s for user %s and entry %s...goint to unresolved" % (handle, user.id, entry.id))
			# We found the handle, so share the entry with the user.
			entry.users.add(contact.target)

	suspiciousHour = dealWithSuspiciousHour(user, utcDate, entry, keeperNumber)

	analytics.logUserEvent(
		user,
		"Created Reminder",
		{
			"Needed Followup": sendFollowup,
			"Was Suspicious Hour": suspiciousHour,
			"In tutorial": isTutorial(user)
		}
	)

	return entry


def updateReminderEntry(user, utcDate, msg, entry, keeperNumber):
	entry.remind_timestamp = utcDate
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

	suspiciousHour = dealWithSuspiciousHour(user, utcDate, entry, keeperNumber)

	analytics.logUserEvent(
		user,
		"Updated Reminder",
		{
			"Was Suspicious Hour": suspiciousHour,
			"In tutorial": isTutorial(user)
		}
	)


#  Send off a response like "I'll remind you Sunday at 9am" or "I'll remind mom Sunday at 9am"
def sendCompletionResponse(user, entry, sendFollowup, keeperNumber):
	tzAwareDate = entry.remind_timestamp.astimezone(user.getTimezone())

	userMsg = msg_util.naturalize(datetime.datetime.now(user.getTimezone()), tzAwareDate)

	handle = "you"

	# If this is a shared reminder then look up the handle to send things out with
	if len(entry.users.all()) > 1:
		for target in entry.users.all():
			if target.id != user.id:
				contact = Contact.fetchByTarget(user, target)
				handle = contact.handle

	toSend = "%s I'll remind %s %s." % (helper_util.randomAcknowledgement(), handle, userMsg)

	# Tutorial gets a special followup message
	if sendFollowup:
		if isTutorial(user):
			toSend = toSend + "\n\n"
			toSend = toSend + "In the future, you can also include a specific time like 'tomorrow morning' or 'Saturday at 3pm'"
		else:
			toSend = toSend + "\n\n"
			toSend = toSend + "If that time doesn't work, tell me what time is better"

	sms_util.sendMsg(user, toSend, None, keeperNumber)


def isReminderHourSuspicious(hourForUser):
	return hourForUser >= 0 and hourForUser <= 6


def getDefaultTime(user):
	tz = user.getTimezone()
	userNow = datetime.datetime.now(tz)

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

	return replaceTime

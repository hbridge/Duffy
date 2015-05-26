import datetime
import pytz
import logging
import re

from peanut.settings import constants

from common import natty_util

from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants
from smskeeper import actions
from smskeeper import helper_util
from smskeeper import analytics

from smskeeper.models import Entry

logger = logging.getLogger(__name__)


# Might need to move these to common constants file at some point.
FROM_TUTORIAL_KEY = "fromtutorial"


# Returns True if the time exists and isn't within 10 seconds of now.
# We check for the 10 seconds to deal with natty phrases that don't really tell us a time (like "today")
def validTime(startDate):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	return not (startDate is None or abs((now - startDate).total_seconds()) < 10)


# Returns True if this message has a valid time and it doesn't look like another command (like another #remind)
# Otherwise False
def isFollowup(startDate, msg):
	return validTime(startDate) and not msg_util.hasLabel(msg)


def process(user, msg, requestDict, keeperNumber):
	text, label, handles = msg_util.getMessagePieces(msg)
	nattyResults = natty_util.getNattyInfo(text, user.getTimezone())

	if len(nattyResults) > 0:
		startDate, newQuery, usedText = nattyResults[0]
	else:
		startDate = None
		newQuery = text

	# If we have an entry id, then that means we just created one.
	# See if what they entered is a valid time and if so, assign it.
	# If not, kick out to normal mode and re-process
	if user.getStateData("entryId"):
		if isFollowup(startDate, msg):
			entry = Entry.objects.get(id=int(user.getStateData("entryId")))
			doRemindMessage(user, startDate, msg, entry.text, False, entry, keeperNumber, requestDict)

			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
			return True
		else:
			# Send back for reprocessing
			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
			return False

	# We don't have an entryId so this is the first time we've been run in this state
	else:
		sendFollowup = False
		if not validTime(startDate):
			startDate = getDefaultTime(user)
			sendFollowup = True

		entry = doRemindMessage(user, startDate, msg, newQuery, sendFollowup, None, keeperNumber, requestDict)

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

	return True


#  Update or create the Entry for the reminder entry and send message to user
def doRemindMessage(user, startDate, msg, query, sendFollowup, entry, keeperNumber, requestDict):
	# if the user created this reminder as "remind me to", we should remove it from the text
	match = re.match('remind me( to)?', query, re.I)
	if match is not None:
		query = query[match.end():].strip()

	isUpdate = entry is not None
	# Need to do this so the add message correctly adds the label
	msgWithLabel = query + " " + keeper_constants.REMIND_LABEL
	if not entry:
		entries, notFoundHandles = actions.add(user, msgWithLabel, requestDict, keeperNumber, False, False)
		entry = entries[0]

	hourForUser = startDate.astimezone(user.getTimezone()).hour
	if (isReminderHourSuspicious(hourForUser) and keeperNumber != constants.SMSKEEPER_TEST_NUM):
		logger.error("Scheduling an alert for %s am local time for user %s, might want to check entry id %s" % (hourForUser, user.id, entry.id))

	# Hack where we add 5 seconds to the time so we support queries like "in 2 hours"
	# Without this, it'll return back "in 1 hour" because some time has passed and it rounds down
	# Have to pass in cleanDate since humanize doesn't use utcnow.  To set to utc then kill the tz
	startDate = startDate.astimezone(user.getTimezone())
	userMsg = msg_util.naturalize(datetime.datetime.now(user.getTimezone()), startDate)

	entry.remind_timestamp = startDate
	entry.keeper_number = keeperNumber
	entry.orig_text = msg
	entry.save()

	toSend = "%s I'll remind you %s." % (helper_util.randomAcknowledgement(), userMsg)

	if sendFollowup:
		if user.getStateData(FROM_TUTORIAL_KEY):
			toSend = toSend + "\n\n"
			toSend = toSend + "In the future, you can also include a specific time like 'tomorrow morning' or 'Saturday at 3pm'"
		else:
			toSend = toSend + "\n\n"
			toSend = toSend + "If that time doesn't work, tell me what time is better"

	sms_util.sendMsg(user, toSend, None, keeperNumber)

	analytics.logUserEvent(
		user,
		"Created Reminder",
		{
			"Was Update": isUpdate,
			"Needed Followup": sendFollowup,
			"Was Suspicious Hour": isReminderHourSuspicious(hourForUser)
		}
	)

	return entry

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

import datetime
import pytz
import humanize
import json
import re

from common import natty_util

from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants
from smskeeper import actions, async

from smskeeper.models import Entry


"""
	Returns True if the time exists and isn't within 10 seconds of now.
	We check for the 10 seconds to deal with natty phrases that don't really tell us a time (like "today")
"""
def validTime(startDate):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	return not (startDate == None or abs((now - startDate).total_seconds()) < 10)

"""
	Returns True if this message has a valid time and it doesn't look like another command (like another #remind)
	Otherwise False
"""
def isFollowup(startDate, msg):
	return validTime(startDate) and not msg_util.hasLabel(msg)

def process(user, msg, requestDict, keeperNumber):
	text, label, handles = msg_util.getMessagePieces(msg)
	startDate, newQuery, usedText = natty_util.getNattyInfo(text, user.timezone)

	# If we have an entry id, then that means we just created one.
	# See if what they entered is a valid time and if so, assign it.
	# If not, kick out to normal mode and re-process
	if user.getStateData("entryId"):
		if isFollowup(startDate, msg):
			entry = Entry.objects.get(id=int(user.getStateData("entryId")))
			doRemindMessage(user, startDate, entry.text, False, entry, keeperNumber, requestDict)

			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
			return True
		else:
			# Send back for reprocessing
			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
			return False

	# We don't have an entryId so this is the first time we've been put into this state
	else:
		sendFollowup = False
		if not validTime(startDate):
			startDate = getDefaultTime(user)
			sendFollowup = True
		entry = doRemindMessage(user, startDate, newQuery, sendFollowup, None, keeperNumber, requestDict)

		if sendFollowup:
			user.setStateData("entryId", entry.id)
		else:
			user.setState(keeper_constants.STATE_NORMAL)
		user.save()

	return True

"""
	Update or create the Entry for the reminder entry and send message to user
"""
def doRemindMessage(user, startDate, query, sendFollowup, entry, keeperNumber, requestDict):
	# Need to do this so the add message correctly adds the label
	msgWithLabel = query + " " + keeper_constants.REMIND_LABEL
	if not entry:
		entry = actions.add(user, msgWithLabel, requestDict, keeperNumber, False)

	# Hack where we add 5 seconds to the time so we support queries like "in 2 hours"
	# Without this, it'll return back "in 1 hour" because some time has passed and it rounds down
	# Have to pass in cleanDate since humanize doesn't use utcnow.  To set to utc then kill the tz
	startDate = startDate.astimezone(pytz.utc)
	startDate = startDate.replace(tzinfo=None)
	userMsg = humanize.naturaltime(startDate + datetime.timedelta(seconds=5))

	entry.remind_timestamp = startDate
	entry.keeper_number = keeperNumber
	entry.save()

	# If we're updating an existing entry we don't need to cancel the other celery task since the processReminder
	# task will make sure the current time is correct for the entry
	async.processReminder.apply_async([entry.id], eta=entry.remind_timestamp)

	toSend = "Got it. Will remind you to %s %s" % (query, userMsg)

	if sendFollowup:
		toSend = toSend + "\n\n"
		toSend = toSend + "If that time doesn't work, tell me what time is better"

	sms_util.sendMsg(user, toSend, None, keeperNumber)

	return entry

def getDefaultTime(user):
	tz = user.getTimezone()
	userNow = datetime.datetime.now(tz)

	# If before 2 pm, remind at 6 pm
	if userNow.hour < 14:
		replaceTime = userNow.replace(hour = 18, minute=0, second=0)
	# If between 2 pm and 5 pm, remind at 9 pm
	elif userNow.hour >= 14 and userNow.hour < 17:
		replaceTime = userNow.replace(hour = 21, minute=0, second=0)
	else:
	# If after 5 pm, remind 9 am next day
		replaceTime = userNow + datetime.timedelta(days=1)
		replaceTime = replaceTime.replace(hour = 9, minute=0, second=0)

	return replaceTime

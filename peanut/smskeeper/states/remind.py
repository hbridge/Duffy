import datetime
import pytz
import humanize
import json
import re

from common import natty_util

from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants
from smskeeper import actions, async

def getStateData(user):
	iteration = None
	originalMsg = None
	if user.state_data:
		data = json.loads(user.state_data)
		iteration = int(data['iteration'])
		originalMsg = data['originalMsg']

	return (iteration, originalMsg)

def saveStateData(user, iteration, originalMsg):
	data = {'iteration': iteration, 'originalMsg': originalMsg}
	user.state_data = json.dumps(data)
	user.save()

#def canProcessMessag(user, msg):


def process(user, msg, requestDict, keeperNumber):
	iteration, originalMsg = getStateData(user)

	text, label, handles = msg_util.getMessagePieces(msg)
	startDate, newQuery, usedText = natty_util.getNattyInfo(text, user.timezone)

	# See if the time that comes back is within a few seconds.
	# If this happens, then we didn't get a time from the user
	if not validTime(startDate):
		if not iteration:
			# TODO(Derek): Update this to pick a default time and let the user know
			sms_util.sendMsg(user, "At what time?", None, keeperNumber)
			saveStateData(user, 1, msg)
		elif iteration == 1:
			sms_util.sendMsg(user, "Sorry, I still didn't understand that.  At what time?", None, keeperNumber)
	else:
		# If we were in a loop, grab the original msg to use text from that
		if originalMsg:
			# First get the used Text from the last message
			startDate, newQuery, usedText = natty_util.getNattyInfo(originalMsg, user.timezone)

			# Now append on the new 'time' (msg) to that message, then pass to Natty
			if not usedText:
				usedText = ""
			newMsg = usedText + " " + msg

			# We want to ignore the newQuery here since we're only sending in time related stuff
			startDate, ignore, usedText = natty_util.getNattyInfo(newMsg, user.timezone)

		# if the user typed reminder as remind me to, we shoudl remove it from the text
		match = re.match('remind me( to)?', newQuery, re.I)
		if match is not None:
			newQuery = newQuery[match.end():].strip()
		doRemindMessage(user, startDate, newQuery, keeperNumber, requestDict)
		user.setState(keeper_constants.STATE_NORMAL)

def doRemindMessage(user, startDate, query, keeperNumber, requestDict):
	# Need to do this so the add message correctly adds the label
	msgWithLabel = query + " " + keeper_constants.REMIND_LABEL
	entry = actions.add(user, msgWithLabel, requestDict, keeperNumber, False)

	# Hack where we add 5 seconds to the time so we support queries like "in 2 hours"
	# Without this, it'll return back "in 1 hour" because some time has passed and it rounds down
	# Have to pass in cleanDate since humanize doesn't use utcnow
	startDate = startDate.replace(tzinfo=None)
	userMsg = humanize.naturaltime(startDate + datetime.timedelta(seconds=5))

	entry.remind_timestamp = startDate
	entry.keeper_number = keeperNumber
	entry.save()

	async.processReminder.apply_async([entry.id], eta=entry.remind_timestamp)

	sms_util.sendMsg(user, "Got it. Will remind you to %s %s" % (query, userMsg), None, keeperNumber)

	user.setState(keeper_constants.STATE_NORMAL)
	user.save()

"""
	Returns True if the time exists and isn't within 10 seconds of now.
	We check for the 10 seconds to deal with natty phrases that don't really tell us a time (like "today")
"""
def validTime(startDate):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	return not (startDate == None or abs((now - startDate).total_seconds()) < 10)

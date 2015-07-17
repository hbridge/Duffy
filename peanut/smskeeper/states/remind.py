import datetime
import logging
import re
import pytz

from smskeeper import keeper_constants
from smskeeper import msg_util, actions
from smskeeper import reminder_util, sms_util

from common import date_util

logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	if dealWithTutorialEdgecases(user, msg, keeperNumber):
		return True, keeper_constants.CLASS_NONE

	nattyResult = reminder_util.getNattyResult(user, msg)
	entries = user.getLastEntries()

	if len(entries) > 1:
		logger.info("In remind state but last entries is more than 1 so going to ignore them")
		entry = None
	elif len(entries) == 1:
		entry = entries[0]
	else:
		entry = None

	# If this is a done or snooze command so kick out to normal which will deal with it
	# Hacky, theres a lot of exception cases here
	if not msg_util.isRemindCommand(msg) and (msg_util.isSnoozeCommand(msg) or (not nattyResult.validTime() and msg_util.isDoneCommand(msg))) and user.isTutorialComplete():
		user.setState(keeper_constants.STATE_NORMAL)
		return False, None

	# If this doesn't look valid then ignore (starts with ok or "sounds good")
	if not looksLikeValidEntry(msg, nattyResult):
		logger.info("User %s: Skipping msg '%s' because it doesn't look valid to me" % (user.id, msg))
		return True, keeper_constants.CLASS_SILENT_NICETY

	# If this is a follow up, update that entry
	if reminder_util.isFollowup(user, entry, msg, nattyResult):
		logger.info("User %s: Doing followup on entry %s with msg %s" % (user.id, entry.id, msg))
		reminder_util.updateReminderEntry(user, nattyResult, msg, entry, keeperNumber, False)

		reminder_util.sendCompletionResponse(user, entry, False, keeperNumber)

		if not user.isTutorialComplete():
			user.setState(keeper_constants.STATE_TUTORIAL_TODO)
			return False, None
		else:
			return True, keeper_constants.CLASS_CORRECTION

	doCreate = False
	# Now, see if this looks like a valid new reminder like it has time info or "remind me"
	# Or if we're in the tutorial
	if shouldCreateReminder(user, nattyResult, msg) or not user.isTutorialComplete():
		doCreate = True
	else:
		# This doesn't look valid for some reason
		# So right here we're confused on what to do since we don't think we should create a reminder
		# If we just came from normal then we know it would have been processed for done msgs, etc...pause
		if user.last_state and user.last_state == keeper_constants.STATE_NORMAL:
			logger.info("User %s: I'm confused with '%s', it could be a new reminder but not sure. nattyResult: %s.  ausing" % (user.id, msg, nattyResult))
			paused = actions.unknown(user, msg, keeperNumber, sendMsg=False)
			if not paused:
				doCreate = True
		else:
			# If we didn't go through normal just now, then try that first.
			# The message could be a valid done command
			# We might end up back here though which we deal with above
			user.setState(keeper_constants.STATE_NORMAL)
			return False, None

	if doCreate:
		sendFollowup = False
		if not nattyResult.validTime() or not user.isTutorialComplete():
			sendFollowup = True

		entry = reminder_util.createReminderEntry(user, nattyResult, msg, sendFollowup, keeperNumber)
		# We set this so it knows what entry was created
		user.setStateData(keeper_constants.LAST_ENTRIES_IDS_KEY, [entry.id])

		# If we're in the tutorial and they didn't give a time, then give a different follow up
		if not nattyResult.validTime() and not user.isTutorialComplete():
			sms_util.sendMsg(user, "Great, and when would you like to be reminded?", None, keeperNumber)

			# Return here and we should come back
			return True, keeper_constants.CLASS_CREATE_TODO
		else:
			reminder_util.sendCompletionResponse(user, entry, sendFollowup, keeperNumber)

		# If we came from the tutorial, then set state and return False so we go back for reprocessing
		if not user.isTutorialComplete():
			user.setState(keeper_constants.STATE_TUTORIAL_TODO)
			return False, None

	# This is used by remind_util to see if something is a followup
	user.setStateData(keeper_constants.LAST_ACTION_KEY, unixTime(date_util.now(pytz.utc)))
	return True, keeper_constants.CLASS_CREATE_TODO


def unixTime(dt):
	epoch = datetime.datetime.utcfromtimestamp(0).replace(tzinfo=pytz.utc)
	delta = dt - epoch
	return int(delta.total_seconds())


def dealWithTutorialEdgecases(user, msg, keeperNumber):
	# If we're coming from the tutorial and we find a message with a zipcode in it...just ignore the whole message
	# Would be great not to have a hack here
	if not user.isTutorialComplete():
		postalCodes = re.search(r'.*(\d{5}(\-\d{4})?)', msg)
		if postalCodes:
			# ignore the message
			return True
	return False


# If we don't have a valid time and its less than 4 words, don't count as a valid entry
# Things like "ok great"
# Eventually we might want to move this over to looking at interesting words.
# Right now that's tough since we'd filter out valid done commands
def looksLikeValidEntry(msg, nattyResult):
	words = msg.split(' ')
	if not nattyResult.validTime() and len(words) < 4 and msg_util.isOkPhrase(msg):
		return False
	return True


# Method to determine if we create a new reminder
# If they
# But if there's no timing info, then don't
def shouldCreateReminder(user, nattyResult, msg):
	if msg_util.isRemindCommand(msg):
		return True
	if not nattyResult.validTime():
		return False

	return True

"""
Temp comment out by Derek due to taking out shared reminders
# See if the entry didn't create. This means there's unresolved handes
if not entry:
	return False  # Send back for reprocessing by unknown handles state
"""


"""
Temp comment out by Derek due to taking out shared reminders
if user.getStateData("fromUnresolvedHandles"):
	logger.info("User %s: Going to deal with unresolved handles for entry %s and user %s" % (user.id, entry.id, user.id))

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
"""

import datetime
import logging
import re

from common import date_util
import pytz
from smskeeper import keeper_constants
from smskeeper import msg_util, actions
from smskeeper import reminder_util
from smskeeper.models import Entry


logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	if dealWithTutorialEdgecases(user, msg, keeperNumber):
		return True

	nattyResult = reminder_util.getNattyResult(user, msg)
	entry = getPreviousEntry(user)

	# If this doesn't look valid then ignore
	if not looksLikeValidEntry(msg, nattyResult):
		logger.info("User %s: Skipping msg '%s' because it doesn't look valid to me" % (user.id, msg))
		return True

	# Create a new reminder
	if not entry:
		sendFollowup = False

		if not validTime(nattyResult) or user.isInTutorial():
			sendFollowup = True

		doCreate = False

		if shouldCreateReminder(user, nattyResult, msg):
			doCreate = True
		else:
			# HACKY
			# So right here we're confused on what to do.
			# lastAction only is set by us, so if we are here again and are confused... try normal
			# route first
			# If that doesn't work, it'll clear this field
			lastAction = user.getStateData("lastAction")
			if lastAction:
				user.setState(keeper_constants.STATE_NORMAL)
				user.save()
				return False
			else:
				paused = actions.unknown(user, msg, keeperNumber, sendMsg=False)
				if not paused:
					doCreate = True

		if doCreate:
			entry = reminder_util.createReminderEntry(user, nattyResult, msg, sendFollowup, keeperNumber)

			"""
			Temp comment out by Derek due to taking out shared reminders
			# See if the entry didn't create. This means there's unresolved handes
			if not entry:
				return False  # Send back for reprocessing by unknown handles state
			"""

			reminder_util.sendCompletionResponse(user, entry, sendFollowup, keeperNumber)

			# If we came from the tutorial, then set state and return False so we go back for reprocessing
			if user.getStateData(keeper_constants.FROM_TUTORIAL_KEY):
				# Note, some behind the scene magic sets the state and state_data for us.  So this call
				# is kind of overwritten.  Done so the tutorial state can worry about its state and formatting
				user.setState(keeper_constants.STATE_TUTORIAL_REMIND)
				# We set this so it knows what entry was created
				user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entry.id)
				user.save()
				return False

			# Always save the entryId state since we always come back into this state.
			# If they don't enter timing info then we kick out
			user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entry.id)
			user.save()
	else:
		# If we have an entry id, then that means we are doing a follow up
		# See if what they entered is a valid time and if so, assign it.
		# If not, kick out to normal mode and re-process

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
		if isFollowup(user, entry, nattyResult):
			isSnooze = user.getStateData(keeper_constants.IS_SNOOZE_KEY)
			logger.info("User %s: Doing followup on entry %s with msg %s" % (user.id, entry.id, msg))
			reminder_util.updateReminderEntry(user, nattyResult, msg, entry, keeperNumber, isSnooze)
			reminder_util.sendCompletionResponse(user, entry, False, keeperNumber)

			return True
		else:
			# Send back for reprocessing
			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
			return False

	user.setStateData(keeper_constants.LAST_ACTION_KEY, unixTime(date_util.now(pytz.utc)))
	user.save()
	return True


# Returns True if the the user entered any type of timing information
def validTime(nattyResult):
	return nattyResult.hadDate or nattyResult.hadTime


def getLastActionTime(user):
	if user.getStateData(keeper_constants.LAST_ACTION_KEY):
		return datetime.datetime.utcfromtimestamp(user.getStateData(keeper_constants.LAST_ACTION_KEY)).replace(tzinfo=pytz.utc)
	else:
		return None


def unixTime(dt):
	epoch = datetime.datetime.utcfromtimestamp(0).replace(tzinfo=pytz.utc)
	delta = dt - epoch
	return int(delta.total_seconds())


# Returns True if this message has a valid time and it doesn't look like another remind command
# If reminderSent is true, then we look for again or snooze which if found, we'll assume is a followup
# Like "remind me again in 5 minutes"
# If the message (without timing info) only is "remind me" then also is a followup due to "remind me in 5 minutes"
# Otherwise False
def isFollowup(user, entry, nattyResult):
	now = date_util.now(pytz.utc)
	if validTime(nattyResult):
		cleanedText = msg_util.cleanedReminder(nattyResult.queryWithoutTiming)  # no "Remind me"
		lastActionTime = getLastActionTime(user)
		isRecentAction = True if (lastActionTime and (now - lastActionTime) < datetime.timedelta(minutes=2)) else False

		# Covers cases where there the cleanedText is "in" or "around"
		if len(cleanedText) <= 2:
			logger.info("User %s: I think this is a followup to %s bc its less than 2 letters" % (user.id, entry.id))
			return True
		# If they write "no, remind me sunday instead" then want to process as followup
		elif msg_util.startsWithNo(nattyResult.queryWithoutTiming):
			logger.info("User %s: I think this is a followup to %s bc it starts with a No" % (user.id, entry.id))
			return True
		elif user.getStateData(keeper_constants.IS_SNOOZE_KEY):
			logger.info("User %s: I think this is a followup to %s bc its a snooze" % (user.id, entry.id))
			return True
		# If we were just editing this entry and the query has only a couple words
		# unless it's a snooze command, in which case it may refer to a different entry
		elif isRecentAction and len(cleanedText.split(' ')) < 3 and not msg_util.isSnoozeCommand(nattyResult.queryWithoutTiming):
			logger.info("User %s: I think this is a followup to %s bc we updated it recently" % (user.id, entry.id))
			return True
		else:
			bestEntry, score = actions.getBestEntryMatch(user, nattyResult.queryWithoutTiming)
			# This could be a new entry due to todos
			# Check to see if there's a fuzzy match to the last entry.  If so, treat as followup
			if bestEntry and bestEntry.id == entry.id and score > 60 and isRecentAction:
				logger.info("User %s: I think '%s' is a followup because it matched entry id %s with score %s" % (user.id, nattyResult.queryWithoutTiming, bestEntry.id, score))
				return True

	return False


def dealWithTutorialEdgecases(user, msg, keeperNumber):
	# If we're coming from the tutorial and we find a message with a zipcode in it...just ignore the whole message
	# Would be great not to have a hack here
	if user.getStateData(keeper_constants.FROM_TUTORIAL_KEY):
		postalCodes = re.search(r'.*(\d{5}(\-\d{4})?)', msg)
		if postalCodes:
			# ignore the message
			return True
	return False


def getPreviousEntry(user):
	entry = None
	if user.getStateData(keeper_constants.ENTRY_ID_DATA_KEY):
		entryId = int(user.getStateData(keeper_constants.ENTRY_ID_DATA_KEY))
		try:
			entry = Entry.objects.get(id=entryId)
		except Entry.DoesNotExist:
			pass

	return entry


# If we don't have a valid time and its less than 4 words, don't count as a valid entry
# Things like "ok great"
def looksLikeValidEntry(msg, nattyResult):
	words = msg.split(' ')
	if not validTime(nattyResult) and len(words) < 4 and msg_util.isOkPhrase(msg):
		return False
	return True


# Method to determine if we create a new reminder.
# If its tutorial, def do it.  But if there's no timing info, then don't
def shouldCreateReminder(user, nattyResult, msg):
	if user.isInTutorial():
		return True
	if msg_util.isRemindCommand(msg):
		return True
	if not validTime(nattyResult):
		return False

	return True

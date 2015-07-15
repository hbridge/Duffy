import logging

from smskeeper import msg_util, actions, reminder_util
from smskeeper import keeper_constants

logger = logging.getLogger(__name__)


# Enter this state after a message was just sent to the user
# See if its a done command. If not, send back for normal processing
def process(user, msg, requestDict, keeperNumber):
	entries = user.getLastEntries()

	if len(entries) == 0:
		logging.info("User %s: Couldn't find any entries with ids %s, kicking to normal" % (user.id, [x.id for x in entries]))
		# Couldn't find entry so try sending back through normal flow
		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return False, None  # Reprocess

	if msg_util.isDoneCommand(msg):
		msgSent, isAll = actions.done(user, msg, keeperNumber)

		if msgSent:
			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
		classification = keeper_constants.CLASS_COMPLETE_TODO_ALL if isAll else keeper_constants.CLASS_COMPLETE_TODO_SPECIFIC
		return True, classification
	# Could be a snooze for the most recent entry
	elif len(entries) == 1:
		entry = entries[0]
		nattyResult = reminder_util.getNattyResult(user, msg)
		if reminder_util.isSnoozeForEntry(user, msg, entry, nattyResult):
			actions.snooze(user, msg, keeperNumber)
			return True, keeper_constants.CLASS_SNOOZE

	logging.info("User %s: I don't think this is a done or followup command to the most recent reminder, so kicking out" % (user.id))
	user.setState(keeper_constants.STATE_NORMAL)

	return False, None  # Reprocess

import logging

from smskeeper import msg_util, actions
from smskeeper import keeper_constants
from smskeeper.models import Entry

logger = logging.getLogger(__name__)


# Enter this state after a message was just sent to the user
# See if its a done command. If not, send back for normal processing
def process(user, msg, requestDict, keeperNumber):
	if not user.getStateData(keeper_constants.ENTRY_IDS_DATA_KEY):
		entryIds = [user.getStateData(keeper_constants.ENTRY_ID_DATA_KEY)]
	else:
		entryIds = user.getStateData(keeper_constants.ENTRY_IDS_DATA_KEY)

	entries = Entry.objects.filter(id__in=entryIds)
	if len(entries) == 0:
		logging.debug("User %s: Couldn't find any entries with ids %s, kicking to normal" % (user.id, entryIds))
		# Couldn't find entry so try sending back through normal flow
		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return False  # Reprocess

	query = msg.lower()

	if msg_util.isDoneCommand(msg):
		msgSent = actions.done(user, msg, keeperNumber, entries)

		if msgSent:
			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
		return True
	# If its a snooze
	elif len(entries) == 1 and ("again" in query or "snooze" in query):
		entry = entries[0]
		logger.debug("User %s: In reminder-sent, doing snooze on entry %s with msg %s" % (user.id, entry.id, msg))

		user.setState(keeper_constants.STATE_REMIND)
		user.setStateData(keeper_constants.IS_SNOOZE_KEY, True)
		user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entries[0].id)
		user.save()

		return False  # Reprocess by state remind
	else:
		logging.debug("User %s: I don't think this is a done or followup command, so kicking out" % (user.id))

		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return False  # Reprocess

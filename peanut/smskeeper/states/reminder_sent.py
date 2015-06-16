import logging

from smskeeper import sms_util, msg_util, actions
from smskeeper import keeper_constants
from smskeeper.models import Entry

logger = logging.getLogger(__name__)


def clearAll(entries):
	# Assume this is done, or done with and clear all
	msgBack = u"Nice! "
	for entry in entries:
		msgBack += u"\u2705"
		entry.hidden = True
		entry.save()
	return msgBack


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

	if msg_util.isDoneCommand(msg):
		if len(msg.split(' ')) <= 2:
			logging.debug("User %s: I think this is a done command for all entries %s since the phrase was short" % (user.id, [x.id for x in entries]))
			msgBack = clearAll(entries)
		else:
			bestMatch, score = actions.getBestEntryMatch(user, msg)

			if score > 80:
				# We got a great hit to something so it was probably specific, just hide that one
				bestMatch.hidden = True
				bestMatch.save()

				logger.info("User %s: I think this is a done command decided to hide entry '%s' (%s) due to score of %s" % (user.id, bestMatch.text, bestMatch.id, score))

				msgBack = u"Nice. \u2705  %s" % bestMatch.text
			else:
				# If the score is low, it probably means we didn't match a specific one, so clear them all
				logging.debug("User %s: I think this is a done command for all entries %s since the score was low: %s" % (user.id, [x.id for x in entries], score))
				msgBack = clearAll(entries)

		sms_util.sendMsg(user, msgBack, None, keeperNumber)
		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return True

	else:
		logging.debug("User %s: I don't think this is a done command, so kicking out" % (user.id))

		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return False  # Reprocess

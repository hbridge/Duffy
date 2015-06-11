import logging

from smskeeper import sms_util, msg_util, actions
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

	if msg_util.isDoneCommand(msg):
		bestMatch, score = actions.getBestEntryMatch(user, msg)

		# If we didn't fuzzy match on anything, assume its all of them
		if score < 50:
			msgBack = u"Nice! "
			for entry in entries:
				msgBack += u"\u2705"
				entry.hidden = True
				entry.save()
			logging.debug("User %s: I think this is a done command for all entries %s and score %s" % (user.id, [x.id for x in entries], score))
		else:
			msgBack = u"Nice. %s  \u2705" % bestMatch.text
			logging.debug("User %s: I think this is a done command for entry %s with text '%s' and score %s" % (user.id, bestMatch.id, bestMatch.text, score))

			bestMatch.hidden = True
			bestMatch.save()

		sms_util.sendMsg(user, msgBack, None, keeperNumber)

		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return True
	else:
		logging.debug("User %s: I don't think this is a done command, so kicking out" % (user.id))

		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return False  # Reprocess

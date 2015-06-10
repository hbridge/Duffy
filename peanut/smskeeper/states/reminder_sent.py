import logging

from smskeeper import sms_util, msg_util, actions
from smskeeper import keeper_constants
from smskeeper.models import Entry

logger = logging.getLogger(__name__)


# Enter this state after a message was just sent to the user
# See if its a done command. If not, send back for normal processing
def process(user, msg, requestDict, keeperNumber):
	entryId = int(user.getStateData(keeper_constants.ENTRY_ID_DATA_KEY))
	try:
		entry = Entry.objects.get(id=entryId)
	except Entry.DoesNotExist:
		# Couldn't find entry so try sending back through normal flow
		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return False  # Reprocess

	if msg_util.isDoneCommand(msg):
		bestMatch, score = actions.getBestEntryMatch(user, msg)

		# If we didn't fuzzy match on anything, assume its the last one we sent a reminder about
		if score < 50:
			msgBack = u"Nice! \u2705"
			bestMatch = entry
		else:
			msgBack = u"Nice. %s  \u2705" % bestMatch.text

		bestMatch.hidden = True
		bestMatch.save()

		sms_util.sendMsg(user, msgBack, None, keeperNumber)

		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return True
	else:
		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return False  # Reprocess

import logging

from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants
from smskeeper.models import Entry

logger = logging.getLogger(__name__)


# Enter this state after a message was just sent to the user
# See if its a done command. If not, send back for normal processing
def process(user, msg, requestDict, keeperNumber):
	entryId = int(user.getStateData(keeper_constants.ENTRY_ID_DATA_KEY))
	entry = Entry.objects.get(id=entryId)

	if msg_util.isDoneCommand(msg):
		entry.hidden = True
		entry.save()

		msgBack = "Nice!"

		sms_util.sendMsg(user, msgBack, None, keeperNumber)

		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return True
	else:
		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		return False  # Reprocess

from smskeeper import async
import logging
import pytz
logger = logging.getLogger(__name__)
from datetime import datetime
from datetime import timedelta

from smskeeper import keeper_constants

DELAY_SECONDS_PER_WORD = 0.2
MIN_DELAY_SECONDS = 1


def sendMsg(user, msg, mediaUrl, keeperNumber, eta=None, manual=False):
	if isinstance(msg, list):
		raise TypeError("Passing a list to sendMsg.  Did you mean sendMsgs?")

	if keeper_constants.isRealKeeperNumber(keeperNumber):
		async.sendMsg.apply_async((user.id, msg, mediaUrl, keeperNumber, manual), eta=eta)
	else:
		# If its CLI or TEST then keep it local and not async.
		async.sendMsg(user.id, msg, mediaUrl, keeperNumber, manual)


def sendMsgs(user, msgList, keeperNumber, sendMessageDividers=True):
	if not isinstance(msgList, list):
		raise TypeError("Passing %s to sendMsg.  Did you mean sendMsg?", type(msgList))

	seconds_delay = 0
	for i, msgTxt in enumerate(msgList):
		scheduledTime = datetime.now(pytz.utc) + timedelta(seconds=seconds_delay)
		logger.debug("scheduling %s at time %s" % (msgTxt, scheduledTime))

		# calc the time for the next message
		wordcount = len(msgTxt.split(" "))
		seconds_delay += max(wordcount * DELAY_SECONDS_PER_WORD, MIN_DELAY_SECONDS)

		# modify the message text if we're supposed to send dividers
		if sendMessageDividers and len(msgList) > 1:
			msgTxt = "%s (%d/%d)" % (msgTxt, i + 1, len(msgList))

		# Call the single method above so it does the right async logic
		sendMsg(user, msgTxt, None, keeperNumber, scheduledTime)

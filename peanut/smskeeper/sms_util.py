from smskeeper import async
import logging
import pytz
logger = logging.getLogger(__name__)
from datetime import datetime
from datetime import timedelta

from peanut.settings import constants

SECONDS_BETWEEN_SEND = 3


def sendMsg(user, msg, mediaUrls, keeperNumber, eta=None):
	if isinstance(msg, list):
		raise TypeError("Passing a list to sendMsg.  Did you mean sendMsgs?")
	if keeperNumber == constants.SMSKEEPER_CLI_NUM:
		async.sendMsg(user.id, msg, mediaUrls, keeperNumber)
	else:
		async.sendMsg.apply_async((user.id, msg, mediaUrls, keeperNumber), eta=eta)


def sendMsgs(user, msgList, keeperNumber):
	if not isinstance(msgList, list):
		raise TypeError("Passing %s to sendMsg.  Did you mean sendMsg?", type(msgList))
	for i, msgTxt in enumerate(msgList):
		scheduledTime = datetime.now(pytz.utc) + timedelta(seconds=i * SECONDS_BETWEEN_SEND)
		logger.debug("scheduling %s at time %s" % (msgTxt, scheduledTime))

		# Call the single method above so it does the right async logic
		sendMsg(user, msgTxt, None, keeperNumber, scheduledTime)

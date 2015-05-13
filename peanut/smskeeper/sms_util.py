from smskeeper import async
import logging
import pytz
logger = logging.getLogger(__name__)
from datetime import datetime
from datetime import timedelta

SECONDS_BETWEEN_SEND = 3


def sendMsg(user, msg, mediaUrls, keeperNumber):
	if isinstance(msg, list):
		raise TypeError("Passing a list to sendMsg.  Did you mean sendMsgs?")
	async.sendMsg(user.id, msg, mediaUrls, keeperNumber)


def sendMsgs(user, msgList, keeperNumber):
	for i, msgTxt in enumerate(msgList):
		scheduledTime = datetime.now(pytz.utc) + timedelta(seconds=i * SECONDS_BETWEEN_SEND)
		logger.debug("scheduling %s at time %s" % (msgTxt, scheduledTime))
		async.sendMsg.apply_async((user.id, msgTxt, None, keeperNumber), eta=scheduledTime)

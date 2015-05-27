from smskeeper import async
import logging
import pytz
logger = logging.getLogger(__name__)
from datetime import datetime
from datetime import timedelta

from peanut.settings import constants

DELAY_SECONDS_PER_WORD = 0.2


def sendMsg(user, msg, mediaUrl, keeperNumber, eta=None, manual=False):
	if isinstance(msg, list):
		raise TypeError("Passing a list to sendMsg.  Did you mean sendMsgs?")

	if isRealKeeperNumber(keeperNumber):
		print "here"
		async.sendMsg.apply_async((user.id, msg, mediaUrl, keeperNumber, manual), eta=eta)
	else:
		# If its CLI or TEST then keep it local and not async.
		async.sendMsg(user.id, msg, mediaUrl, keeperNumber, manual)


def sendMsgs(user, msgList, keeperNumber):
	if not isinstance(msgList, list):
		raise TypeError("Passing %s to sendMsg.  Did you mean sendMsg?", type(msgList))

	seconds_delay = 0
	for i, msgTxt in enumerate(msgList):
		scheduledTime = datetime.now(pytz.utc) + timedelta(seconds=seconds_delay)
		logger.debug("scheduling %s at time %s" % (msgTxt, scheduledTime))

		# calc the time for the next message
		wordcount = len(msgTxt.split(" "))
		seconds_delay += wordcount * DELAY_SECONDS_PER_WORD

		# Call the single method above so it does the right async logic
		sendMsg(user, msgTxt, None, keeperNumber, scheduledTime)


def isRealKeeperNumber(keeperNumber):
	return keeperNumber != constants.SMSKEEPER_CLI_NUM and keeperNumber != constants.SMSKEEPER_TEST_NUM


def isTestKeeperNumber(keeperNumber):
	return keeperNumber == constants.SMSKEEPER_TEST_NUM

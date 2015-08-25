import pytz
import json

from datetime import timedelta

from twilio import TwilioRestException

from celery.utils.log import get_task_logger

from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper.models import Message, User

from strand import notifications_util
from common import slack_logger, date_util

from peanut.celery import app
from smskeeper.whatsapp import whatsapp_util

logger = get_task_logger(__name__)


# This is used for testing, it gets mocked out
# The sendmsg method calls it as well for us in the command line interface
def recordOutput(msgText, doPrint=False):
	if doPrint:
		print msgText


# Note: Adding params here will break existing entries queued up
@app.task
def asyncSendMsg(userId, msgText, mediaUrl, keeperNumber, manual, stopOverride, classification):
	logger.info("User %s: asyncSendMsg to keeperNumber: %s", userId, keeperNumber)
	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		logger.error("User %s: Tried to send message to nonexistent user", userId)
		return

	if user.state == keeper_constants.STATE_STOPPED and not stopOverride:
		logger.warning("User %s: Tried to send msg '%s' but they are in state stopped" % (user.id, msgText))
		return
	if keeperNumber == "web":  # don't record responses to web messages in history
		return

	if user.overrideKeeperNumber:
		keeperNumber = user.overrideKeeperNumber

	msgJson = {"Body": msgText, "To": user.phone_number, "From": keeperNumber, "MediaUrls": mediaUrl}
	# Create the message now, but only save it if we know we successfully sent the message
	message = Message(user=user, incoming=False, msg_json=json.dumps(msgJson), manual=manual, classification=classification)

	if type(msgText) == unicode:
		msgText = msgText.encode('utf-8')

	if keeperNumber is None or keeperNumber in [keeper_constants.SMSKEEPER_CLI_NUM, keeper_constants.SMSKEEPER_WEB_NUM] or "test" in keeperNumber:
		recordOutput(msgText, (keeperNumber == keeper_constants.SMSKEEPER_CLI_NUM))
		message.save()
	elif keeperNumber == "ignore":
		logger.debug("User %s: Not sending msg '%s' because keeper number was null")
		# Don't save the message, wasn't sent
		pass
	elif whatsapp_util.isWhatsappNumber(keeperNumber):
		logger.info("User %s: sending whatsapp message: %s" % (userId, msgText))
		whatsapp_util.sendMessage(user.phone_number, msgText, mediaUrl, keeperNumber)
		message.save()
		slack_logger.postMessage(message, keeper_constants.SLACK_CHANNEL_FEED)
	else:
		if user.getKeeperNumber() != keeperNumber:
			logger.error("User %s: This user's keeperNumber %s doesn't match the keeperNumber passed into asyncSendMsg: %s... fixing" % (user.id, user.getKeeperNumber(), keeperNumber))
			keeperNumber = user.getKeeperNumber()
		try:
			logger.info("User %s: Sending '%s'" % (user.id, msgText))
			notifications_util.sendSMSThroughTwilio(user.phone_number, msgText, mediaUrl, keeperNumber)
			message.save()
			slack_logger.postMessage(message, keeper_constants.SLACK_CHANNEL_FEED)
		except TwilioRestException as e:
			logger.error("User %s: Got TwilioRestException with message %s" % (userId, e))


def sendMsg(user, msg, mediaUrl=None, keeperNumber=None, eta=None, manual=False, stopOverride=False, classification=None):
	if isinstance(msg, list):
		raise TypeError("Passing a list to sendMsg.  Did you mean sendMsgs?")

	if keeperNumber is None:
		keeperNumber = user.getKeeperNumber()

	msg = msg_util.renderMsg(msg)
	if keeper_constants.isRealKeeperNumber(keeperNumber):
		asyncSendMsg.apply_async((user.id, msg, mediaUrl, keeperNumber, manual, stopOverride, classification), eta=eta)
	else:
		# If its CLI or TEST then keep it local and not async.
		asyncSendMsg(user.id, msg, mediaUrl, keeperNumber, manual, stopOverride, classification)


def sendDelayedMsg(user, msg, delaySeconds, keeperNumber=None, classification=None):
	if isinstance(msg, list):
		raise TypeError("Passing a list to sendMsg.  Did you mean sendMsgs?")

	if keeperNumber is None:
		keeperNumber = user.getKeeperNumber()

	msg = msg_util.renderMsg(msg)
	args = (user.id, msg, None, keeperNumber, False, False, classification)
	if keeper_constants.isRealKeeperNumber(keeperNumber):
		eta = date_util.now(pytz.utc) + timedelta(seconds=delaySeconds)
		asyncSendMsg.apply_async(*args, eta=eta)
	else:
		# If its CLI or TEST then keep it local and not async.
		asyncSendMsg(*args)


def sendMsgs(user, msgList, keeperNumber=None, sendMessageDividers=True, stopOverride=False, classification=None):
	if not isinstance(msgList, list):
		raise TypeError("Passing %s to sendMsg.  Did you mean sendMsg?", type(msgList))

	if keeperNumber is None:
		keeperNumber = user.getKeeperNumber()

	seconds_delay = 0
	for i, msgTxt in enumerate(msgList):
		scheduledTime = date_util.now(pytz.utc) + timedelta(seconds=seconds_delay)
		logger.debug("scheduling %s at time %s" % (msgTxt, scheduledTime))

		# calc the time for the next message
		wordcount = len(msgTxt.split(" "))
		seconds_delay += max(wordcount * keeper_constants.DELAY_SECONDS_PER_WORD, keeper_constants.MIN_DELAY_SECONDS)

		# modify the message text if we're supposed to send dividers
		if sendMessageDividers and len(msgList) > 1:
			msgTxt = "%s (%d/%d)" % (msgTxt, i + 1, len(msgList))

		# Call the single method above so it does the right async logic
		sendMsg(user, msgTxt, None, keeperNumber, scheduledTime, stopOverride=stopOverride, classification=classification)

	return seconds_delay

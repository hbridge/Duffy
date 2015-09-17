import pytz
import json
import datetime
import random

from twilio import TwilioRestException

from celery.utils.log import get_task_logger

from smskeeper import keeper_constants, keeper_strings
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
def asyncSendMsg(userId, msgText, mediaUrl, keeperNumber, manual, stopOverride, classification, sendToSlack):
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

		if sendToSlack:
			slack_logger.postMessage(message, keeper_constants.SLACK_CHANNEL_FEED)
	else:
		if user.getKeeperNumber() != keeperNumber:
			logger.error("User %s: This user's keeperNumber %s doesn't match the keeperNumber passed into asyncSendMsg: %s... fixing" % (user.id, user.getKeeperNumber(), keeperNumber))
			keeperNumber = user.getKeeperNumber()
		try:
			logger.info("User %s: Sending '%s'" % (user.id, msgText))
			notifications_util.sendSMSThroughTwilio(user.phone_number, msgText, mediaUrl, keeperNumber)
			message.save()
			if sendToSlack:
				slack_logger.postMessage(message, keeper_constants.SLACK_CHANNEL_FEED)
		except TwilioRestException as e:
			logger.error("User %s: Got TwilioRestException with message '%s' and exception %s" % (userId, msgText, e))


def sendMsg(user, msg, mediaUrl=None, keeperNumber=None, eta=None, manual=False, stopOverride=False, classification=None, sendToSlack=True):
	if isinstance(msg, list):
		raise TypeError("Passing a list to sendMsg.  Did you mean sendMsgs?")

	if keeperNumber is None:
		keeperNumber = user.getKeeperNumber()

	msg = msg_util.renderMsg(msg)
	if keeper_constants.isRealKeeperNumber(keeperNumber):
		asyncSendMsg.apply_async((user.id, msg, mediaUrl, keeperNumber, manual, stopOverride, classification, sendToSlack), eta=eta)
	else:
		# If its CLI or TEST then keep it local and not async.
		asyncSendMsg(user.id, msg, mediaUrl, keeperNumber, manual, stopOverride, classification, sendToSlack)


def sendDelayedMsg(user, msg, delaySeconds, keeperNumber=None, classification=None):
	eta = date_util.now(pytz.utc) + datetime.timedelta(seconds=delaySeconds)
	logger.info("User %d: sendDelayedMsg %s %s", user.id, delaySeconds, msg)

	sendMsg(user, msg, eta=eta, keeperNumber=keeperNumber, classification=classification)


def sendMsgs(user, msgList, keeperNumber=None, sendMessageDividers=False, stopOverride=False, classification=None):
	if not isinstance(msgList, list):
		raise TypeError("Passing %s to sendMsg.  Did you mean sendMsg?", type(msgList))

	if keeperNumber is None:
		keeperNumber = user.getKeeperNumber()

	seconds_delay = 0
	for i, msgTxt in enumerate(msgList):
		scheduledTime = date_util.now(pytz.utc) + datetime.timedelta(seconds=seconds_delay)
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


# When this runs, check to see if there's been any further messages sent by the user
# If so, then don't execute
# If not, then send out a confused message
def maybeSendConfusedMsg(user, keeperNumber=None):
	if keeperNumber is None:
		keeperNumber = user.getKeeperNumber()

	now = date_util.now(pytz.utc)

	if keeper_constants.isRealKeeperNumber(keeperNumber):
		eta = now + datetime.timedelta(minutes=2)
		asyncMaybeSendConfusedMsg.apply_async((user.id, date_util.unixTime(now)), eta=eta)
	else:
		pass
		# Tests should call this manually
		# asyncMaybeSendConfusedMsg(user.id, date_util.unixTime(now))


@app.task
def asyncMaybeSendConfusedMsg(userId, msgTimeSinceEpoch):
	user = User.objects.get(id=userId)
	dt = datetime.datetime.fromtimestamp(msgTimeSinceEpoch)
	messagesAfter = Message.objects.filter(user=user, added__gt=dt)

	if len(messagesAfter) == 0:
		logger.debug("User %s: Sending out confused message because 0 messages came after my time %s", user.id, dt)
		# Send out confused message
		sendMsg(user, random.choice(keeper_strings.UNKNOWN_COMMAND_PHRASES), classification=keeper_constants.OUTGOING_UNKNOWN)
	else:
		logger.debug("User %s: Didn't send out confused message because %s messages came after my time %s", user.id, len(messagesAfter), dt)


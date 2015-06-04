import pytz
import json

from datetime import datetime
from datetime import timedelta

from twilio import TwilioRestException

from celery.utils.log import get_task_logger

from peanut.settings import constants

from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper.models import Message, User

from strand import notifications_util
from common import slack_logger

from peanut.celery import app

DELAY_SECONDS_PER_WORD = 0.2
MIN_DELAY_SECONDS = 1

logger = get_task_logger(__name__)


# This is used for testing, it gets mocked out
# The sendmsg method calls it as well for us in the command line interface
def recordOutput(msgText, doPrint=False):
	if doPrint:
		print msgText


@app.task
def asyncSendMsg(userId, msgText, mediaUrl, keeperNumber, manual=False):
	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		logger.error("Tried to send message to nonexistent user with id: %d", userId)
		return

	if user.state == keeper_constants.STATE_STOPPED and user.getStateData("step") and user.getStateData("step") == 1:
		logger.warning("Tried to send msg %s to user %s who is in state stopped" % (msgText, user.id))
		return

	msgJson = {"Body": msgText, "To": user.phone_number, "From": keeperNumber, "MediaUrls": mediaUrl}
	# Create the message now, but only save it if we know we successfully sent the message
	message = Message(user=user, incoming=False, msg_json=json.dumps(msgJson), manual=manual)

	if type(msgText) == unicode:
		msgText = msgText.encode('utf-8')

	if keeperNumber == constants.SMSKEEPER_CLI_NUM:
		# This is used for command line interface commands
		recordOutput(msgText, True)
		message.save()
	elif keeperNumber == constants.SMSKEEPER_TEST_NUM:
		recordOutput(msgText, False)
		message.save()
	else:
		try:
			logger.info("Sending %s to %s" % (msgText, str(user.phone_number)))
			notifications_util.sendSMSThroughTwilio(user.phone_number, msgText, mediaUrl, keeperNumber)
			message.save()
			slack_logger.postMessage(message, keeper_constants.SLACK_CHANNEL_FEED)
		except TwilioRestException as e:
			logger.info("Got TwilioRestException for user %s with message %s.  Setting to state stopped" % (userId, e))
			user.setState(keeper_constants.STATE_STOPPED)
			user.save()


def sendMsg(user, msg, mediaUrl, keeperNumber, eta=None, manual=False):
	if isinstance(msg, list):
		raise TypeError("Passing a list to sendMsg.  Did you mean sendMsgs?")

	msg = msg_util.renderMsg(msg)
	if keeper_constants.isRealKeeperNumber(keeperNumber):
		asyncSendMsg.apply_async((user.id, msg, mediaUrl, keeperNumber, manual), eta=eta)
	else:
		# If its CLI or TEST then keep it local and not async.
		asyncSendMsg(user.id, msg, mediaUrl, keeperNumber, manual)


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

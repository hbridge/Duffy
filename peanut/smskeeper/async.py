from __future__ import absolute_import
import datetime
import pytz
import json

from twilio import TwilioRestException


"""
TEMP REMOVE
see if we really need this.  If something breaks with async, talk to Derek
Removed due to circular dependencies with admin.py

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()
"""

from django.conf import settings

from celery.utils.log import get_task_logger
from peanut.celery import app
from peanut.settings import constants
from smskeeper import tips
from smskeeper.models import Entry
from smskeeper.models import Message
from smskeeper.models import User
from smskeeper import keeper_constants

from strand import notifications_util
from common import slack_logger

logger = get_task_logger(__name__)


# Returns true if:
# The remind timestamp ends in 0 or 30 minutes and its within 10 minutes of then
# The current time is after the remind timestamp but we're within 5 minutes
# Hidden is false
def shouldRemindNow(entry):
	if entry.hidden:
		return False

	now = datetime.datetime.now(pytz.utc)
	if entry.remind_timestamp.minute == 0 or entry.remind_timestamp.minute == 30:
		# If we're within 10 minutes, so alarm goes off at 9:50 if remind is at 10
		return (now + datetime.timedelta(minutes=10) > entry.remind_timestamp)
	else:
		# The current time is after the remind timestamp but we're within 5 minutes
		return (entry.remind_timestamp < now and entry.remind_timestamp > now - datetime.timedelta(minutes=5))


def processReminder(entry):
	msg = "Hi! Friendly reminder: %s" % entry.text

	for user in entry.users.all():
		sendMsg(user.id, msg, None, entry.keeper_number)

		# Now set to remind, incase they send back some snooze messaging
		user.setState(keeper_constants.STATE_REMIND, saveCurrent=True)
		user.setStateData("entryId", entry.id)
		user.setStateData("reminderSent", True)
		user.save()

	entry.hidden = True
	entry.save()


@app.task
def processAllReminders():
	entries = Entry.objects.filter(remind_timestamp__isnull=False, hidden=False)

	logger.debug("Found %s entries to eval" % len(entries))

	for entry in entries:
		if shouldRemindNow(entry):
			logger.info("Processing entry: %s for users %s" % (entry.id, entry.users.all()))
			processReminder(entry)


@app.task
def sendTips(keeperNumber=None):
	if not keeperNumber:
		keeperNumber = settings.KEEPER_NUMBER

	users = User.objects.all()
	for user in users:
		tip = tips.selectNextTip(user)
		if tip:
			sendTipToUser(tip, user, keeperNumber)


def sendTipToUser(tip, user, keeperNumber):
	sendMsg(user.id, tip.render(user.name), tip.mediaUrl, keeperNumber)
	tips.markTipSent(user, tip)


def str_now_1():
	return str(datetime.now())


@app.task
def sendMsg(userId, msgText, mediaUrl, keeperNumber, manual=False):
	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		logger.error("Tried to send message to nonexistent user with id: %d", userId)
		return

	if user.state == keeper_constants.STATE_STOPPED:
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


# This is used for testing, it gets mocked out
# The sendmsg method calls it as well for us in the command line interface
def recordOutput(msgText, doPrint=False):
	if doPrint:
		print msgText


@app.task
def testCelery():
	logger.debug("Celery task ran.")

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


@app.task
def processReminder(entryId):
	logger.debug("Starting reminder process for entry %s" % (entryId))
	entry = Entry.objects.get(id=entryId)
	now = datetime.datetime.now(pytz.utc)

	# See if this entry is valid for reminder
	# It needs to not be hidden
	# As well as the remind_timestamp be within a few seconds of now
	if not entry.hidden and abs((now - entry.remind_timestamp).total_seconds()) < 300:
		msg = "Hi! Friendly reminder: %s" % entry.text

		for user in entry.users.all():
			sendMsg(user.id, msg, None, entry.keeper_number)

		entry.hidden = True
		entry.save()


@app.task
def processAllReminders():
	entries = Entry.objects.filter(remind_timestamp__isnull=False, hidden=False)

	logger.debug("Found %s entries to eval" % len(entries))
	now = datetime.datetime.now(pytz.utc)
	for entry in entries:
		if entry.remind_timestamp < now and entry.remind_timestamp > now - datetime.timedelta(minutes=5):
			logger.info("Processing entry: %s for users %s" % (entry.id, entry.users.all()))
			processReminder(entry.id)


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
def sendMsg(userId, msgText, mediaUrl, keeperNumber):
	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		logger.error("Tried to send message to nonexistent user with id: %d", userId)
		return

	if user.state == keeper_constants.STATE_STOPPED:
		logger.warning("Tried to send msg %s to user %s who is in state stopped" % (msgText, user.id))
		return

	msgJson = {"Body": msgText, "To": user.phone_number, "From": keeperNumber, "MediaUrls": mediaUrl}
	message = Message(user=user, incoming=False, msg_json=json.dumps(msgJson))

	if type(msgText) == unicode:
		msgText = msgText.encode('utf-8')

	if keeperNumber == constants.SMSKEEPER_CLI_NUM:
		# This is used for command line interface commands
		recordOutput(msgText, True)
	elif keeperNumber == constants.SMSKEEPER_TEST_NUM:
		recordOutput(msgText, False)
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

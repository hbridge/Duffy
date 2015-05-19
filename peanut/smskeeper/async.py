from __future__ import absolute_import
import sys
import os
import datetime
import pytz
import json
import logging


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
			sendMsg(user.id, tip.render(user.name), None, keeperNumber)
			tips.markTipSent(user, tip)


def str_now_1():
	return str(datetime.now())


@app.task
def sendMsg(userId, msgText, mediaUrls, keeperNumber):
	try:
		user = User.objects.get(id=userId)
	except User.DoesNotExist:
		logger.error("Tried to send message to nonexistent user with id: %d", userId)
		return

	msgJson = {"Body": msgText, "To": user.phone_number, "From": keeperNumber, "MediaUrls": mediaUrls}
	msg = Message.objects.create(user=user, incoming=False, msg_json=json.dumps(msgJson))

	if type(msgText) == unicode:
		msgText = msgText.encode('utf-8')

	if keeperNumber == constants.SMSKEEPER_CLI_NUM:
		# This is used for command line interface commands
		recordOutput(msgText, True)
	elif keeperNumber == constants.SMSKEEPER_TEST_NUM:
		recordOutput(msgText, False)
	else:
		if mediaUrls:
			notifications_util.sendSMSThroughTwilio(user.phone_number, msgText, mediaUrls, keeperNumber)
		else:
			notifications_util.sendSMSThroughTwilio(user.phone_number, msgText, None, keeperNumber)
		logger.info("Sending %s to %s" % (msgText, str(user.phone_number)))
		slack_logger.postMessage(msg, keeper_constants.SLACK_CHANNEL_FEED)


# This is used for testing, it gets mocked out
# The sendmsg method calls it as well for us in the command line interface
def recordOutput(msgText, doPrint=False):
	if doPrint:
		print msgText


@app.task
def testCelery():
	logger.debug("Celery task ran.")

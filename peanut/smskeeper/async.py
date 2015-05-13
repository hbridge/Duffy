from __future__ import absolute_import
import sys
import os
import datetime
import pytz
import json
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.conf import settings

from celery.utils.log import get_task_logger
from peanut.celery import app
from peanut.settings import constants
from smskeeper import tips
from smskeeper.models import Entry
from smskeeper.models import Message
from smskeeper.models import User
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


def shouldSendUserTip(user):
	if not user.completed_tutorial:
		return False
	if user.disable_tips or user.tip_frequency_days == 0:
		return False
	if not user.last_tip_sent:
		return True
	else:
		# must use datetime.datetime.now and not utcnow as the test mocks datetime.now
		dt = datetime.datetime.now(pytz.utc) - user.last_tip_sent
		tip_frequency_seconds = (user.tip_frequency_days * 24 * 60 * 60) - (60 * 60)  # - is a fudge factor of an hour
		if dt.total_seconds() >= tip_frequency_seconds:
			return True
	return False


@app.task
def sendTips(keeperNumber=None):
	if not keeperNumber:
		keeperNumber = settings.KEEPER_NUMBER

	users = User.objects.all()
	for user in users:
		if shouldSendUserTip(user):
			sentTips = list()
			if user.sent_tips:
				sentTips = user.sent_tips.split(",")
			for tip in tips.SMSKEEPER_TIPS:
				if tip["identifier"] not in sentTips:
					sendMsg(user.id, tips.renderTip(tip, user.name), None, keeperNumber)
					sentTips.append(tip["identifier"])
					user.sent_tips = ",".join(sentTips)
					user.last_tip_sent = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
					user.save()
					break


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
		slack_logger.postMessage(msg)

"""
	This is used for testing, it gets mocked out
	The sendmsg method calls it as well for us in the command line interface
"""
def recordOutput(msgText, doPrint=False):
	if doPrint:
		print msgText


@app.task
def testCelery():
	logger.debug("Celery task ran.")

from __future__ import absolute_import
import sys
import os

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut.celery import app

from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

from smskeeper.models import Entry
from smskeeper.models import User
from smskeeper import sms_util
from smskeeper import tips
import datetime
from django.conf import settings
import pytz
import time


@app.task
def processReminder(entryId):
	entry = Entry.objects.get(id=entryId)

	if not entry.hidden:
		msg = "Hi! Friendly reminder: %s" % entry.text

		for user in entry.users.all():
			sms_util.sendMsg(user, msg, None, entry.keeper_number)

		entry.hidden = True
		entry.save()


TIP_FREQUENCY_SECS = 60 * 60 * 23  # 23 hours in seconds


def shouldSendUserTip(user):
	if not user.last_tip_sent:
		return True
	else:
		# must use datetime.datetime.now and not utcnow as the test mocks datetime.now
		dt = datetime.datetime.now(pytz.utc) - user.last_tip_sent
		if dt.total_seconds() > TIP_FREQUENCY_SECS:
			return True
	return False


@app.task
def sendTips():
	print "sending tips"
	users = User.objects.all()
	for user in users:
		if shouldSendUserTip(user):
			print "evaling tips to send to user: %s" % (user.phone_number)
			sentTips = list()
			if user.sent_tips:
				sentTips = user.sent_tips.split(",")
			for tip in tips.SMSKEEPER_TIPS:
				if tip["identifier"] not in sentTips:
					print "sending %s to %s" % (tip["identifier"], user.phone_number)
					for msg in tip["messages"]:
						sms_util.sendMsg(user, msg, None, settings.KEEPER_NUMBER)
						time.sleep(1)
					sentTips.append(tip["identifier"])
					user.sent_tips = ",".join(sentTips)
					user.last_tip_sent = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
					user.save()
					break


def str_now_1():
	return str(datetime.now())

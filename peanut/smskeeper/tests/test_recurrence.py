import datetime
import pytz
from mock import patch
import logging
import sys

from smskeeper import cliMsg, async, keeper_constants
from smskeeper.models import Entry, Message

import test_base

import emoji
from smskeeper import time_utils
from common import date_util
from datetime import timedelta

logger = logging.getLogger()
logger.level = logging.DEBUG


@patch('common.date_util.utcnow')
class SMSKeeperRecurCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, dateMock):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		super(SMSKeeperRecurCase, self).setupUser(True, True, productId=1)

	"""
	Commenting out for now since this is no longer valid
	def test_no_time(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to run")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("by 9am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals(13, entry.remind_timestamp.hour)  # 9 am EST
	"""

	def test_every_day(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind me to put on socks every day")

		entry = Entry.objects.filter(label="#reminders").order_by("-added")[0]
		self.assertEquals(keeper_constants.RECUR_DAILY, entry.remind_recur)
		self.assertNotIn("every day", entry.text)

	def test_every_week(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind me to get cash every Tuesday at noon")

		entry = Entry.objects.filter(label="#reminders").order_by("-added")[0]
		self.assertEquals(keeper_constants.RECUR_WEEKLY, entry.remind_recur)
		self.assertNotIn("every", entry.text)
		self.assertNotIn("Tuesday", entry.text)

	def test_every_month(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind me to pay mortgage and best buy every 16th of each month")

		entry = Entry.objects.filter(label="#reminders").order_by("-added")[0]
		self.assertEquals(keeper_constants.RECUR_MONTHLY, entry.remind_recur)
		self.assertNotIn("month", entry.text)

	def test_every_weekday(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind me every monday-friday at 10:45am to leave for work")

		entry = Entry.objects.filter(label="#reminders").order_by("-added")[0]
		self.assertEquals(keeper_constants.RECUR_WEEKDAYS, entry.remind_recur)
		self.assertNotIn("monday-friday", entry.text)

	def test_non_recur(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind me to only do this once")

		entry = Entry.objects.filter(label="#reminders").order_by("-added")[0]
		self.assertEquals(keeper_constants.RECUR_DEFAULT, entry.remind_recur)

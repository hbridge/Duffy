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

	def test_one_time_reminder(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "remind me wake up at 10am")

		entry = Entry.objects.get(label="#reminders")

		entry.remind_recur = keeper_constants.RECUR_ONE_TIME
		entry.save()

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Wake up", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("Wake up", self.getOutput(mock))

	def test_weekly_reminder(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "remind me wake up at 10am every monday")

		entry = Entry.objects.get(label="#reminders")

		entry.remind_recur = keeper_constants.RECUR_WEEKLY
		entry.save()

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Wake up", self.getOutput(mock))
			self.assertNotIn("Just let", self.getOutput(mock))

		"""
		Commenting out since now we're pinging every day
		# Should be nothing for digest
		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertEquals("", self.getOutput(mock))

		"""

		# Go forward a week...and now it should work
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(weeks=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Wake up", self.getOutput(mock))

		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(weeks=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Wake up", self.getOutput(mock))

		# But not on Tuesdays
		self.setNow(dateMock, self.TUE_9AM + datetime.timedelta(weeks=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("Wake up", self.getOutput(mock))

	def test_daily_reminder(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "remind me wake up at 10am everyday")

		entry = Entry.objects.get(label="#reminders")

		entry.remind_recur = keeper_constants.RECUR_DAILY
		entry.save()

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Wake up", self.getOutput(mock))

		# Should be in the digest
		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Wake up", self.getOutput(mock))

		# Should be sent out at 10 am
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Wake up", self.getOutput(mock))

	def test_daily_reminder_with_end(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "remind me wake up at 10am everyday")

		entry = Entry.objects.get(label="#reminders")

		entry.remind_recur = keeper_constants.RECUR_DAILY
		entry.remind_recur_end = self.WED_9AM
		entry.save()

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Wake up", self.getOutput(mock))

		# Should be sent out at 10 am Tue
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Wake up", self.getOutput(mock))

		# Now that its Wed, it shouldn't go out
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=2))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertEqual("", self.getOutput(mock))

	# Pretend that the async processing didn't mark something as hidden.
	# This is simply here to validate that this bug is tracked
	def test_daily_reminder_with_end_bug_in_processing(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "remind me wake up at 10am everyday")

		entry = Entry.objects.get(label="#reminders")

		entry.remind_recur = keeper_constants.RECUR_DAILY
		entry.remind_recur_end = self.WED_9AM
		entry.save()

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Wake up", self.getOutput(mock))

		# Explicitly don't run the job on Tuesday
		entry = Entry.objects.filter(label="#reminders").first()
		self.assertFalse(entry.hidden)

		# Now that its Wed, it shouldn't go out
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=2))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertEqual("", self.getOutput(mock))

	def test_monthly_reminder(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "remind me pay bills on the 16th of every month")

		entry = Entry.objects.get(label="#reminders")

		entry.remind_recur = keeper_constants.RECUR_MONTHLY
		entry.save()

		self.setNow(dateMock, datetime.datetime(2015, 6, 16, 13, 0, 0, tzinfo=pytz.utc))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Pay bills", self.getOutput(mock))

		# Shouldn't be in the digest
		self.setNow(dateMock, datetime.datetime(2015, 7, 15, 13, 0, 0, tzinfo=pytz.utc))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("Pay bills", self.getOutput(mock))

		# Should be
		self.setNow(dateMock, datetime.datetime(2015, 7, 16, 13, 0, 0, tzinfo=pytz.utc))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Pay bills", self.getOutput(mock))

	def test_weekday_reminder(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM - datetime.timedelta(days=1))

		# right now, parsing of this phrase doesn't do well, it picks out just monday
		cliMsg.msg(self.testPhoneNumber, "remind me every monday-friday at 10am to wake up")
		cliMsg.msg(self.testPhoneNumber, "monday at 10am")

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

		# Tuesday yes
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

		# Wednesday yes
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=2))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

		# Thursday yes
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=3))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

		# Friday yes
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=4))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

		# Saturday no
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=5))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertEqual("", self.getOutput(mock))

		# Sunday no
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=6))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertEqual("", self.getOutput(mock))

		# Monday yes
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=7))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

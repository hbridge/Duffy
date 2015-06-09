import datetime
import pytz

from mock import patch
from testfixtures import Replacer
from testfixtures import test_datetime

from smskeeper import cliMsg, keeper_constants, async
from smskeeper.models import Entry

from common import natty_util

import test_base


class SMSKeeperTodoCase(test_base.SMSKeeperBaseCase):

	def setupUser(self):
		super(SMSKeeperTodoCase, self).setupUser(True, True, productId=1)

	def test_no_time(self):
		self.setupUser()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to run")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("around 9am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals(13, entry.remind_timestamp.hour)  # 9 am EST

	def test_tomorrow_no_time(self):
		self.setupUser()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to pick up my sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("9 am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals("I need to pick up my sox", entry.text)

	def test_two_entries(self):
		self.setupUser()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to pick up my sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		firstEntry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals("I need to pick up my sox", firstEntry.text)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to buy tickets next week")
			self.assertIn("Mon", self.getOutput(mock))

		secondEntry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals("I need to buy tickets", secondEntry.text)

		self.assertNotEqual(firstEntry.id, secondEntry.id)

	def test_weekend_no_time(self):
		self.setupUser()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to buy detergent this weekend")
			if (datetime.datetime.now(self.getTestUser().getTimezone()).weekday() == 4):  # Its Friday, so check for tmr
				self.assertIn("tomorrow", self.getOutput(mock))
			else:
				self.assertIn("Sat", self.getOutput(mock))
			self.assertNotIn("9 am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals("I need to buy detergent", entry.text)

	def test_weekend_with_time(self):
		self.setupUser()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to prep dinner sat at 5 pm")
			if (datetime.datetime.now(self.getTestUser().getTimezone()).weekday() == 4):  # Its Friday, so check for tmr
				self.assertIn("tomorrow", self.getOutput(mock))
			else:
				self.assertIn("Sat", self.getOutput(mock))
			self.assertIn("around 5pm", self.getOutput(mock))

	# Make sure that "today" still returns stuff later in the day for todos
	def test_today_from_9am(self):
		self.setupUser()
		with Replacer() as r:
			with patch('common.natty_util.getNattyInfo') as mocked:
				tz = self.getTestUser().getTimezone()
				now = datetime.datetime.now(self.getTestUser().getTimezone())
				# Try with 9 am EST
				testDt = test_datetime(now.year, now.month, now.day, 9, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = [natty_util.NattyResult(testDt.now(pytz.utc), "I buy stuff later", "today", True, False)]
				with patch('smskeeper.sms_util.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "I buy stuff later today")
					# Should be 6 pm, so 9 hours
					self.assertIn("today around 6pm", self.getOutput(mock))

	def test_today_from_3pm(self):
		self.setupUser()
		with Replacer() as r:
			with patch('common.natty_util.getNattyInfo') as mocked:
				tz = self.getTestUser().getTimezone()
				now = datetime.datetime.now(tz)
				# Try with 3 pm EST
				testDt = test_datetime(now.year, now.month, now.day, 15, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = [natty_util.NattyResult(testDt.now(pytz.utc), "I buy stuff later", "today", True, False)]
				with patch('smskeeper.sms_util.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "I buy stuff later today")
					# Should be 9 pm, so 6 hours
					self.assertIn("today around 9pm", self.getOutput(mock))

	def test_today_from_10pm(self):
		self.setupUser()
		with Replacer() as r:
			with patch('common.natty_util.getNattyInfo') as mocked:
				tz = self.getTestUser().getTimezone()
				now = datetime.datetime.now(self.getTestUser().getTimezone())
				# Try with 10 pm EST
				testDt = test_datetime(now.year, now.month, now.day, 22, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = [natty_util.NattyResult(testDt.now(pytz.utc), "I buy stuff later", "today", True, False)]
				with patch('smskeeper.sms_util.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "I buy stuff later today")
					# Should be 9 am next day, so in 11 hours
					self.assertIn("tomorrow", self.getOutput(mock))

			r.replace('smskeeper.states.remind.datetime.datetime', datetime.datetime)

	def test_question(self):
		self.setupUser()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Are you my daddy?")
			self.assertIn(self.getOutput(mock), keeper_constants.UNKNOWN_COMMAND_PHRASES)

	# Make sure first reminder we send snooze tip, then second we don't
	def test_done_hides(self):
		self.setupUser()

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.get(label="#reminders")

		# Make sure the snooze tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("let me know when you're done", self.getOutput(mock))

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done!")
			self.assertIn("Nice!", self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertTrue(entry.hidden)

	# Make sure we create a new entry instead of a followup
	@patch('common.date_util.utcnow')
	@patch('common.natty_util.getNattyInfo')
	def test_create_new_after_reminder(self, nattyMock, dateMock):
		self.setupUser()

		self.setNow(dateMock, self.MON_8AM)
		self.setupNatty(nattyMock, self.MON_8AM, "Remind me go poop", "in 1 minute")

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		firstEntry = Entry.objects.filter(label="#reminders").last()

		# Make sure the snooze tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(firstEntry)
			self.assertIn("let me know when you're done", self.getOutput(mock))

		# Make sure we create a new entry and don't treat as a followup
		self.setupNatty(nattyMock, self.WEEKEND, "I need to go biking", "this weekend")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to go biking this weekend")
			self.assertIn("Sat", self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		secondEntry = Entry.objects.filter(label="#reminders").last()
		self.assertNotEqual(firstEntry.id, secondEntry.id)

	# Make sure first reminder we send snooze tip, then second we don't
	def test_done_fuzzy_one_word_match(self):
		self.setupUser()

		cliMsg.msg(self.testPhoneNumber, "buy that thing I need")
		cliMsg.msg(self.testPhoneNumber, "send email to alex")
		cliMsg.msg(self.testPhoneNumber, "poop in the woods")

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "done with email")
			self.assertIn("Nice!", self.getOutput(mock))
			self.assertIn("send email to alex", self.getOutput(mock))

		entry = Entry.objects.get(text="send email to alex")
		self.assertTrue(entry.hidden)

		# Make sure we create a new entry instead of a followup
	@patch('common.date_util.utcnow')
	@patch('common.natty_util.getNattyInfo')
	def test_process_daily_digest(self, nattyMock, dateMock):
		self.setupUser()

		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			self.setupNatty(nattyMock, self.NO_TIME, "I need to run", "")
			cliMsg.msg(self.testPhoneNumber, "I need to run")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("around 9am", self.getOutput(mock))

		# Make sure it was made for Tue 9am
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals(2, entry.remind_timestamp.day)
		self.assertEquals(13, entry.remind_timestamp.hour)

		# Nothing for digest yet
		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest("test")
			self.assertEquals("", self.getOutput(mock))

		# Now set to tomorrow at 9am, when the reminder is set for
		self.setNow(dateMock, self.TUE_858AM)

		# Shouldn't send in the normal processReminders
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertEquals("", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		# Digest should kicks off
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest("test")
			self.assertIn("I need to run", self.getOutput(mock))




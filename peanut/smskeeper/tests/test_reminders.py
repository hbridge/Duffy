import datetime
import pytz
from mock import patch

from testfixtures import Replacer
from testfixtures import test_datetime

from smskeeper.models import Entry
from smskeeper import cliMsg
from smskeeper import async

import test_base


class SMSKeeperReminderCase(test_base.SMSKeeperBaseCase):

	def test_reminders_basic(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop tmr")
			self.assertIn("tomorrow", self.getOutput(mock))

		self.assertIn("#reminders", Entry.fetchAllLabels(self.user))

	def test_reminders_no_hashtag(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to poop tmr")
			self.assertNotIn("remind me to", self.getOutput(mock))
			self.assertIn("tomorrow", self.getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "reminders")
			self.assertIn("poop", self.getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "clear reminders")
			cliMsg.msg(self.testPhoneNumber, "reminders")
			self.assertNotIn("poop", self.getOutput(mock))

	# This test is here to make sure the ordering of fetch vs reminders is correct
	def test_reminders_fetch(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#reminders")
			self.assertIn("reminders", self.getOutput(mock))

	def test_reminders_no_time_followup(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop")
			self.assertIn("If that time doesn't work", self.getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

	def test_reminders_with_time_followup(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			now = datetime.datetime.now(pytz.utc)
			twoDays = now + datetime.timedelta(days=2)
			dayPhrase = twoDays.strftime("%a")  # Wed or Thur
			cliMsg.msg(self.testPhoneNumber, "actually, 2 days from now")
			self.assertIn(dayPhrase, self.getOutput(mock))

	def test_reminders_two_in_row(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop")
			self.assertIn("If that time doesn't work", self.getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind pee tomorrow")
			cliMsg.msg(self.testPhoneNumber, "#remind")
			self.assertIn("pee", self.getOutput(mock))

	def test_reminders_defaults(self):
		self.setupUser(True, True)

		# Emulate the user sending in a reminder without a time for 9am, 3 pm and 10 pm
		# Need to use replacer since we save these objects so need to be real datetimes
		with Replacer() as r:
			with patch('humanize.time._now') as mocked:
				tz = pytz.timezone('US/Eastern')
				# Try with 9 am EST
				testDt = test_datetime(2020, 01, 01, 9, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)

				# humanize.time._now should always return utcnow because that's what the
				# server's time is set in
				mocked.return_value = testDt.utcnow()
				with patch('smskeeper.async.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 6 pm, so 9 hours
					self.assertIn("today around 6pm", self.getOutput(mock))

				# Try with 3 pm EST
				testDt = test_datetime(2020, 01, 01, 15, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = testDt.utcnow()
				with patch('smskeeper.async.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 9 pm, so 6 hours
					self.assertIn("today around 9pm", self.getOutput(mock))

				# Try with 10 pm EST
				testDt = test_datetime(2020, 01, 01, 22, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = testDt.utcnow()
				with patch('smskeeper.async.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 9 am next day, so in 11 hours
					self.assertIn("tomorrow around 9am", self.getOutput(mock))

			r.replace('smskeeper.states.remind.datetime.datetime', datetime.datetime)

	def test_reminders_middle_of_sentence(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "at 2pm tomorrow remind me to remind kate about her list")
			self.assertIn("tomorrow", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")

		self.assertEqual("remind kate about her list", entry.text)
		self.assertEqual(18, entry.remind_timestamp.hour)

	def test_reminders_tomorrow_9_am(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me tomorrow to go poop")
			self.assertIn("tomorrow around 9am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual("go poop", entry.text)

		# 9 am ETC, so 13 UTC
		self.assertEqual(13, entry.remind_timestamp.hour)

	def test_reminders_commas(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, "remind me to poop, then poop again")

		entry = Entry.objects.get(label="#reminders")

		self.assertIn("poop, then poop again", entry.text)

	def test_func_shouldRemindNow(self):
		self.setupUser(True, True)

		dt = datetime.datetime(2020, 01, 01, 10, 0, 0, tzinfo=pytz.utc)
		entryEven = Entry(creator=self.getTestUser(), text="blah", remind_timestamp=dt)

		dt = datetime.datetime(2020, 01, 01, 10, 15, 0, tzinfo=pytz.utc)
		entryOdd = Entry(creator=self.getTestUser(), text="blah", remind_timestamp=dt)

		with Replacer() as r:
			# This is an hour before, shouldn't remind now
			testDt = test_datetime(2020, 01, 01, 9, 0, 0, tzinfo=pytz.utc)
			r.replace('smskeeper.async.datetime.datetime', testDt)

			ret = async.shouldRemindNow(entryEven)
			self.assertFalse(ret)

			ret = async.shouldRemindNow(entryOdd)
			self.assertFalse(ret)

			# This 10 minutes before and minutes is 0 so should remind
			testDt = test_datetime(2020, 01, 01, 9, 50, 1, tzinfo=pytz.utc)
			r.replace('smskeeper.async.datetime.datetime', testDt)
			ret = async.shouldRemindNow(entryEven)
			self.assertTrue(ret)

			# This has an odd minute so shouldn't fire
			ret = async.shouldRemindNow(entryOdd)
			self.assertFalse(ret)

			# Now we're past the actual time, so should fire
			testDt = test_datetime(2020, 01, 01, 10, 15, 1, tzinfo=pytz.utc)
			r.replace('smskeeper.async.datetime.datetime', testDt)
			ret = async.shouldRemindNow(entryOdd)
			self.assertTrue(ret)

	def test_at_preference(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me at 9am to add 1.25 hrs")
			self.assertIn("around 9am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual("add 1.25 hrs", entry.text)

		# 9 am ETC, so 13 UTC
		self.assertEqual(13, entry.remind_timestamp.hour)

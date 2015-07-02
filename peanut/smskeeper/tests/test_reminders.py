import datetime
import pytz
from mock import patch

from smskeeper.models import Entry
from smskeeper import cliMsg
from smskeeper import async

import test_base


@patch('common.date_util.utcnow')
class SMSKeeperReminderCase(test_base.SMSKeeperBaseCase):
	def setupUser(self, dateMock):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		return super(SMSKeeperReminderCase, self).setupUser(True, True)

	def test_reminders_basic(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop tmr")
			self.assertIn("tomorrow", self.getOutput(mock))

		self.assertIn("#reminders", Entry.fetchAllLabels(self.user))

	def test_reminders_no_hashtag(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to poop tmr")
			self.assertNotIn("remind me to", self.getOutput(mock))
			self.assertIn("tomorrow", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "reminders")
			self.assertIn("poop", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "clear reminders")
			cliMsg.msg(self.testPhoneNumber, "reminders")
			self.assertNotIn("poop", self.getOutput(mock))

	# This test is here to make sure the ordering of fetch vs reminders is correct
	def test_reminders_fetch(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#reminders")
			self.assertIn("reminders", self.getOutput(mock))

	def test_now(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "nothing right now")
			self.assertEqual("", self.getOutput(mock))

	def test_reminders_with_time_followup(self, dateMock):
		self.setupUser(dateMock)
		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "actually, 2 days from now")
			self.assertIn("Wed", self.getOutput(mock))

	# Deal with a follow up of "remind me this evening" which looks like a new reminder
	# but it isn't
	def test_remind_me_followup(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me poop tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		origEntry = Entry.objects.filter(label="#reminders").last()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me on Sunday 7pm")
			self.assertIn("7pm", self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure we didn't create a new entry.  Wanted to edit the first one
		self.assertEqual(origEntry.id, entry.id)
		self.assertEqual(entry.remind_timestamp.hour, 23)  # 7 EST, so 11 UTC

	def test_reminders_two_in_row(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind poop")
			self.assertIn("If that time doesn't work", self.getOutput(mock))

		self.setNow(dateMock, self.MON_9AM)
		cliMsg.msg(self.testPhoneNumber, "#remind pee tomorrow")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "reminders")

			# Make sure pee shows up as a seperate entry
			self.assertIn("pee", self.getOutput(mock))

	def test_reminders_defaults(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind something today")
			self.assertIn("today by 6pm", self.getOutput(mock))

		# Try with 3 pm EST
		self.setNow(dateMock, self.MON_3PM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind blah today")
			self.assertIn("today by 9pm", self.getOutput(mock))

		# Try with 10 pm EST
		self.setNow(dateMock, self.MON_10PM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind ahchuu today")
			self.assertIn("tomorrow", self.getOutput(mock))

	def test_reminders_middle_of_sentence(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "at 2pm tomorrow remind me to remind kate about her list")
			self.assertIn("tomorrow", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")

		self.assertEqual("remind kate about her list", entry.text)
		self.assertEqual(18, entry.remind_timestamp.hour)

	def test_reminders_tomorrow_9_am(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me tomorrow to go poop")
			self.assertIn("tomorrow", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual("go poop", entry.text)

		# 9 am ETC, so 13 UTC
		self.assertEqual(13, entry.remind_timestamp.hour)

	def test_reminders_commas(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind me to poop, then poop again tomorrow")

		entry = Entry.objects.get(label="#reminders")

		self.assertIn("poop, then poop again", entry.text)

	def test_func_should_remind_now_even(self, dateMock):
		self.setupUser(dateMock)

		dt = datetime.datetime(2020, 01, 01, 10, 0, 0, tzinfo=pytz.utc)
		entry = Entry(creator=self.getTestUser(), text="blah", remind_timestamp=dt)

		# This is an hour before, shouldn't remind now
		dateMock.return_value = datetime.datetime(2020, 01, 01, 9, 0, 0, tzinfo=pytz.utc)

		ret = async.shouldRemindNow(entry)
		self.assertFalse(ret)

		# This 10 minutes before and minutes is 0 so should remind
		dateMock.return_value = datetime.datetime(2020, 01, 01, 9, 50, 1, tzinfo=pytz.utc)
		ret = async.shouldRemindNow(entry)
		self.assertTrue(ret)

		# Make it look like we just sent out a reminder by setting last_notified and updated
		entry.remind_last_notified = datetime.datetime(2020, 01, 01, 9, 50, 1, tzinfo=pytz.utc)
		entry.updated = datetime.datetime(2020, 01, 01, 9, 50, 1, tzinfo=pytz.utc)

		# Now set for a minute later and make sure we don't fire again
		dateMock.return_value = datetime.datetime(2020, 01, 01, 9, 51, 1, tzinfo=pytz.utc)
		ret = async.shouldRemindNow(entry)
		self.assertFalse(ret)

		# Now set the remind timestamp  like it was snoozed for an hour one minute later
		# Should fire
		entry.remind_timestamp = datetime.datetime(2020, 01, 01, 10, 51, 0, tzinfo=pytz.utc)
		entry.remind_last_notified = None
		dateMock.return_value = datetime.datetime(2020, 01, 01, 10, 51, 1, tzinfo=pytz.utc)
		ret = async.shouldRemindNow(entry)
		self.assertTrue(ret)

	def test_func_should_remind_now_odd(self, dateMock):
		self.setupUser(dateMock)

		dt = datetime.datetime(2020, 01, 01, 10, 15, 0, tzinfo=pytz.utc)
		entry = Entry(creator=self.getTestUser(), text="blah", remind_timestamp=dt)

		# This is an hour before, shouldn't remind now
		dateMock.return_value = datetime.datetime(2020, 01, 01, 9, 0, 0, tzinfo=pytz.utc)
		ret = async.shouldRemindNow(entry)
		self.assertFalse(ret)

		# This has an odd minute so shouldn't fire
		dateMock.return_value = datetime.datetime(2020, 01, 01, 9, 50, 0, tzinfo=pytz.utc)
		ret = async.shouldRemindNow(entry)
		self.assertFalse(ret)

		# Now we're past the actual time, so should fire
		dateMock.return_value = datetime.datetime(2020, 01, 01, 10, 15, 1, tzinfo=pytz.utc)
		ret = async.shouldRemindNow(entry)
		self.assertTrue(ret)

		# Make it look like we just sent out a reminder by setting last_notified and updated
		entry.remind_last_notified = datetime.datetime(2020, 01, 01, 10, 15, 1, tzinfo=pytz.utc)
		entry.updated = datetime.datetime(2020, 01, 01, 10, 15, 1, tzinfo=pytz.utc)

		# Now we're past the actual time, but we were just notified, so shouldn't fire
		dateMock.return_value = datetime.datetime(2020, 01, 01, 10, 15, 2, tzinfo=pytz.utc)
		ret = async.shouldRemindNow(entry)
		self.assertFalse(ret)

		# Now set the remind timestamp  like it was snoozed for an hour one minute later
		# Should fire
		entry.remind_timestamp = datetime.datetime(2020, 01, 01, 11, 16, 0, tzinfo=pytz.utc)
		entry.remind_last_notified = None
		dateMock.return_value = datetime.datetime(2020, 01, 01, 11, 16, 1, tzinfo=pytz.utc)
		ret = async.shouldRemindNow(entry)
		self.assertTrue(ret)

	def test_at_preference(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me at 10AM to add 1.25 hrs")
			self.assertIn("by 10am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual("add 1.25 hrs", entry.text)

		# 10 am ETC, so 14 UTC
		self.assertEqual(14, entry.remind_timestamp.hour)

	# Make sure we swap out around for "at"
	# Don't want to use mocks for this one since we want to test the whole flow
	def test_around(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "can you remind me next Thursday around 9am")
			self.assertNotIn("tomorrow", self.getOutput(mock))

	def test_single_low_number(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me tomorrow at 4 to email Itai about city year intro to lightsail via Nate.")
			self.assertIn("by 4pm", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual("email Itai about city year intro to lightsail via Nate", entry.text)

		# 4 pm ETC, so 18 UTC
		self.assertEqual(20, entry.remind_timestamp.hour)

	# Test snooze functionality by setting a reminder, firing the reminder, then sending back a snooze message
	def test_snooze_normal(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.get(label="#reminders")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("go poop", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "snooze for 1 hour")

		entries = Entry.objects.filter(label="#reminders")

		self.assertEqual(1, len(entries))

		snoozedEntry = entries[0]
		# Make sure the entries are the same
		self.assertEqual(entry.id, snoozedEntry.id)

		# Make sure the snoozedEntry is now an hour later
		self.assertEqual(snoozedEntry.remind_timestamp.hour, (self.MON_8AM + datetime.timedelta(hours=1)).hour)

	# Make sure that we can say "remind me in 1 hour" for a snooze
	def test_snooze_with_remind_me(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.get(label="#reminders")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("go poop", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "remind me in 1 hour")

		entries = Entry.objects.filter(label="#reminders")

		self.assertEqual(1, len(entries))

		snoozedEntry = entries[0]
		# Make sure the entries are the same
		self.assertEqual(entry.id, snoozedEntry.id)

		# Make sure the snoozedEntry is now an hour later
		self.assertEqual(snoozedEntry.remind_timestamp.hour, (self.MON_8AM + datetime.timedelta(hours=1)).hour)

	# Test snooze functionality by setting a reminder, firing the reminder, then sending back a snooze message
	def test_snooze_again_at_number_please(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.get(label="#reminders")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("go poop", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "remind me again at 3 please")

		entries = Entry.objects.filter(label="#reminders")

		self.assertEqual(1, len(entries))

		snoozedEntry = entries[0]
		# Make sure the entries are the same
		self.assertEqual(entry.id, snoozedEntry.id)

		# Make sure the snoozedEntry is now an hour later
		self.assertEqual(snoozedEntry.remind_timestamp.hour, self.MON_3PM.hour)


	# Test snooze functionality by:
	# Setting a reminder
	# Change state to help
	# firing the reminder
	# snoozing
	# followup to snoozing
	def test_snooze_change_state_and_followup(self, dateMock):
		self.setupUser(dateMock)

		# Similar code as before but not doing asserts here to save code
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Move to help state to see if it gets saved
		cliMsg.msg(self.testPhoneNumber, "help")
		entry = Entry.objects.get(label="#reminders")
		async.processReminder(entry)

		# Now do our snoozes
		cliMsg.msg(self.testPhoneNumber, "snooze for 1 hour")
		cliMsg.msg(self.testPhoneNumber, "actually, 2 hours")

		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(1, len(entries))
		snoozedEntry = entries[0]

		# Make sure the entries are the same
		self.assertEqual(entry.id, snoozedEntry.id)

		# Make sure the snoozedEntry is now an hour later
		self.assertEqual(snoozedEntry.remind_timestamp.hour, (self.TUE_8AM + datetime.timedelta(hours=2)).hour)

	def test_followup_only_time(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to poop tomorrow at 10am")
			self.assertIn("by 10am", self.getOutput(mock))

		origEntry = Entry.objects.get(label="#reminders")
		cliMsg.msg(self.testPhoneNumber, "Actually, do 2pm")

		entries = Entry.objects.filter(label="#reminders")

		# Make sure we didn't create a new entry
		self.assertEqual(1, len(entries))
		entry = entries[0]
		self.assertEqual("poop", entry.text)

		# Look for Friday 2 pm
		self.assertEqual(origEntry.remind_timestamp.day, entry.remind_timestamp.day)
		self.assertEqual(origEntry.remind_timestamp.month, entry.remind_timestamp.month)
		self.assertEqual(18, entry.remind_timestamp.hour)

	# These next 2 tests are pretty similar but still nice to have
	def test_followup_only_day(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "Remind me to poop Sunday at 11am")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Actually, do tomorrow")
			self.assertIn("tomorrow by 11am", self.getOutput(mock))

		self.assertEqual(1, len(Entry.objects.filter(label="#reminders")))

	def test_reminders_no_time_followup(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me poop")
			self.assertIn("If that time doesn't work", self.getOutput(mock))

		origEntry = Entry.objects.get(label="#reminders")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "sunday")
			self.assertIn("Sun", self.getOutput(mock))

		newEntry = Entry.objects.get(label="#reminders")  # Should crash if more than 1 created

		# Make sure the times are the same
		self.assertEqual(origEntry.remind_timestamp.hour, newEntry.remind_timestamp.hour)

	"""
	TO MAKE PASS:

	# Test cases which have two times, but the closer one (we normally default to) is incorrect
	# Assume that the correct time always starts at the begining of the msg
	def test_first_time_correct(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me tomorrow morning that rehearsal for my wedding is at 630pm")
			self.assertIn("by 9am", self.getOutput(mock))


	# Test cases which have two times, but the closer one (we normally default to) is incorrect
	# Assume that the correct time always starts at the begining of the msg
	def test_followup_with_starting_text(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to go poop tomorrow morning")
			self.assertIn("by 8am", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "can you remind me around 6pm?")
			self.assertIn("by 6pm", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(1, len(entries))
		self.assertEqual(entries[0].remind_timestamp.hour, 22)  # 6 EST, so 10 UTC

	def test_day_of_month_without_specific_month(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I also need you to remind me to say happy birthday to a friend on the 11th at 12 am")
			self.assertIn("by 12am", self.getOutput(mock))

		entry = Entry.objects.filter(label="#reminders").last()
		self.assertEqual(entry.remind_timestamp.day, 11)  # 6 EST, so 10 UTC
	def test_single_number(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me my 3 algebra assignments are due Dec 7")
			self.assertIn("by 9am", self.getOutput(mock))
	def test_phone_numbers(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to call North East Medical Services (415) 391-9686 monday at 11 am")
			self.assertNotIn("tomorrow", self.getOutput(mock))

	def test_two_dates_far_away(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me on September 5 that I have appointment with Becca on September 6 at 12:30 PM")
			self.assertIn("Sat the 5th", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual(13, entry.remind_timestamp.hour)  # Make sure its 9am EST


	def test_time_with_dash(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me Cheer practice from 5:30-7:30")
			self.assertIn("by 5:30pm", self.getOutput(mock))
	"""

	# Covers the case of "100 and" which with a bad regex got turned into "1:00 and" due to the a
	def test_numbers_which_have_and_after(self, dateMock):
		self.setupUser(dateMock)
		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:

			cliMsg.msg(self.testPhoneNumber, "Remind me to pay my sister 100 and keep 45 in my bank and give 50 to my mom for my bill on Thursday")
			self.assertIn("Thu", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")

		# Make sure it picked out Thursday
		self.assertEqual(3, entry.remind_timestamp.weekday())

	def test_next_week_becomes_monday(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:

			cliMsg.msg(self.testPhoneNumber, "Remind me to poop next week")
			self.assertIn("Mon", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")

		# Make sure next week translates to Monday 9 am
		self.assertEqual(0, entry.remind_timestamp.weekday())

	# Deal with 3 digit numbers that should be timing info
	def test_three_digit_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to buy stuff at 520p")
			self.assertIn("at 5:20pm", self.getOutput(mock))

			entry = Entry.objects.filter(label="#reminders").last()
			self.assertEqual("buy stuff", entry.text)

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call hubby at 930")
			self.assertIn("by 9:30", self.getOutput(mock))

			entry = Entry.objects.filter(label="#reminders").last()
			self.assertEqual("call hubby", entry.text)

		# Make sure two seperate entries were create
		self.assertEquals(2, len(Entry.objects.filter(label="#reminders")))

	# Make sure first 3 tips are "done", and 4th is snooze
	def test_mini_tips(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")
		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure the done tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("Just let me know when you're done", self.getOutput(mock))

		self.setNow(dateMock, self.MON_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")
		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure the done tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("Let me know when you're done", self.getOutput(mock))

		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")
		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure the done tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("Btw, let me know when you're done", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_8AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop2 in 1 minute")
		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure we grabbed the correct reminder
		self.assertEqual(entry.text, "go poop2")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("Btw, you can always snooze", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop3 in 1 minute")
		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure we grabbed the correct reminder
		self.assertEqual(entry.text, "go poop3")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertNotIn("Btw, you can always snooze", self.getOutput(mock))

		# Make sure this isn't set... mini tips shouldn't set this
		self.assertFalse(self.getTestUser().last_tip_sent)


	"""
	Commenting out by Derek since we're pausing shared reminders
	def test_shared_reminder_regex(self, dateMock):
		handle = msg_util.getReminderHandle("remind mom to take her pill tomorrow morning")
		self.assertEquals(handle, "mom")

		handle = msg_util.getReminderHandle("remind mom: take your pill tomorrow morning")
		self.assertEquals(handle, "mom")

		handle = msg_util.getReminderHandle("remind mom about the tv show")
		self.assertEquals(handle, "mom")

		handle = msg_util.getReminderHandle("at 2pm tomorrow remind mom about the tv show")
		self.assertEquals(handle, "mom")

	def test_shared_reminder_normal(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
			self.assertIn("What's mom's phone number?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, phoneNumber)
			self.assertIn("I'll remind mom tomorrow by 8am", self.getOutput(mock))

		# Make sure other user was created successfully
		otherUser = User.objects.get(phone_number=phoneNumber)
		self.assertEqual(otherUser.state, keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER)

		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure entries were created correctly
		self.assertEquals("take her pill", entry.text)
		self.assertEquals(2, len(entry.users.all()))

	def test_shared_reminder_when_already_created(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, "+16505555555")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind mom to go poop Sunday at 10 am")
			self.assertIn("10am", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")

		# Make sure entries were created correctly
		self.assertEquals(2, len(entries))
		self.assertEquals("go poop", entries[1].text)

	def test_shared_reminder_correct_for_me(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind myself to take pill tomorrow morning")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "no, remind me")
			self.assertIn("I'll remind you tomorrow by 8am", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")

		# Make sure entries were created correctly
		self.assertEquals(1, len(entries))
		self.assertEquals("take pill", entries[0].text)


	Derek commenting out for now.
	This is an exception case where a state should handle a nicety
	def test_shared_reminder_nicety(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "thanks")
			# Make sure
			self.assertIn("No problem", self.getOutput(mock))


	def test_shared_reminder_other_person_tell_me_more(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "tell me more")
			# See if it goes into tutorial
			self.assertIn("what's your name?", self.getOutput(mock))

	def test_shared_reminder_other_person_paused(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		cliMsg.msg(phoneNumber, "wtf")
		otherUser = User.objects.get(phone_number=phoneNumber)
		self.assertTrue(otherUser.paused)

	def test_shared_reminder_processed(self, dateMock):
		phoneNumber = "+16505555555"
		user = self.setupUser(dateMock)

		user.name = "Bob"
		user.save()

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill in one minute")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.get(label="#reminders")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("Bob wanted me", self.getOutput(mock))
			self.assertIn("take her pill", self.getOutput(mock))

	def test_shared_reminder_snooze(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill in one minute")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		# Make the user look like they've been using the product
		otherUser = User.objects.get(phone_number=phoneNumber)
		otherUser.completed_tutorial = True
		otherUser.setState(keeper_constants.STATE_NORMAL)
		otherUser.save()

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.get(label="#reminders")
		async.processReminder(entry)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "snooze 1 hour")
			self.assertIn("later", self.getOutput(mock))
	"""

	def test_followup_if_starts_with_no(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to get gas in my car before next week")
			self.assertIn("Mon", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "no, remind me this Sunday")
			self.assertIn("Sun", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "don't do that remind me this Wednesday")
			self.assertIn("tomorrow", self.getOutput(mock))

		self.assertEqual(1, len(Entry.objects.filter(label="#reminders")))

	@patch('common.natty_util.getNattyInfo')
	def test_only_day_of_month(self, nattyMock, dateMock):
		self.setupUser(dateMock)  # This is on June 2nd

		cliMsg.msg(self.testPhoneNumber, "Remind me about pooping at 9pm on the 4th")

		arg, kargs = nattyMock.call_args
		self.assertEquals("Remind me about pooping at 9pm on June 4th", arg[0])

		cliMsg.msg(self.testPhoneNumber, "Remind me about pooping at 9pm on the 1st")

		# Should be first of next month
		arg, kargs = nattyMock.call_args
		self.assertEquals("Remind me about pooping at 9pm on July 1st", arg[0])

		cliMsg.msg(self.testPhoneNumber, "Remind me about pooping at 9pm on the 20th")

		arg, kargs = nattyMock.call_args
		self.assertEquals("Remind me about pooping at 9pm on June 20th", arg[0])

	def test_ish(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to poop 7ish")
			self.assertIn("later today by 7pm", self.getOutput(mock))

		self.assertEqual("poop", Entry.objects.get(label="#reminders").text)

	def test_message_warp(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to pay my bills tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		self.assertEqual("pay your bills", Entry.objects.get(label="#reminders").text)


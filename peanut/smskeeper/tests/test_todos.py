import datetime
from mock import patch

from smskeeper import cliMsg, async, keeper_constants
from smskeeper.models import Entry, Message

import test_base

import emoji
from smskeeper import time_utils
from common import date_util
from datetime import timedelta


@patch('common.date_util.utcnow')
class SMSKeeperTodoCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, dateMock):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		super(SMSKeeperTodoCase, self).setupUser(True, True, productId=1)

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

	def test_single_word(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "kk")
			self.assertEquals("", self.getOutput(mock))

		self.assertEquals(0, len(Entry.objects.filter(label="#reminders")))

	def test_tomorrow_no_time(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to pick up my sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("9 am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals("pick up your sox", entry.text)

	def test_two_entries(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I want to pick up my sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		self.setNow(dateMock, self.mockedDate + timedelta(hours=1))  # prevent squashing
		firstEntry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals("pick up your sox", firstEntry.text)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to buy tickets next week")
			self.assertIn("Mon", self.getOutput(mock))

		secondEntry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals("buy tickets", secondEntry.text)

		self.assertNotEqual(firstEntry.id, secondEntry.id)

	def test_weekend_no_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to buy detergent this weekend")
			self.assertIn("Sat", self.getOutput(mock))
			self.assertNotIn("9 am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals("buy detergent", entry.text)

	def test_weekend_with_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to prep dinner sat at 5 pm")
			self.assertIn("Sat", self.getOutput(mock))
			self.assertIn("by 5pm", self.getOutput(mock))

	def test_today(self, dateMock):
		self.setupUser(dateMock)

		# Try with 8 am EST
		self.setNow(dateMock, self.TUE_8AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "go shopping later today")
			# Should be 6 pm, so 9 hours
			self.assertIn("today by 6pm", self.getOutput(mock))

		# Try with 3 pm EST
		self.setNow(dateMock, self.TUE_3PM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "watch tv later today")
			# Should be 9 pm, so 6 hours
			self.assertIn("today by 9pm", self.getOutput(mock))

		# Try with 10 pm EST
		self.setNow(dateMock, self.TUE_10PM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "bowling later today")
			# Should be 9 am next day, so in 11 hours
			self.assertIn("tomorrow", self.getOutput(mock))

	# Make sure first reminder we send snooze tip, then second we don't
	def test_done_hides(self, dateMock):
		self.setupUser(dateMock)

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

	# Make sure first reminder we send snooze tip, then second we don't
	def test_done_works_after_two_reminders(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "Thanks!")
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 5 minute")
		cliMsg.msg(self.testPhoneNumber, "I need to buy a dozen sox in 1 minute")

		self.assertEqual(2, len(Entry.objects.filter(label="#reminders")))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		async.processReminder(entry)

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done!")
			self.assertIn("Nice!", self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertTrue(entry.hidden)

	# This checks against a bug where we fuzzy matched to "done" to something that wasn't just fired
	def test_done_only_evals_recent_reminder(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "text dan tomorrow")
		cliMsg.msg(self.testPhoneNumber, "call court on the phone tomorrow")

		self.assertEqual(2, len(Entry.objects.filter(label="#reminders")))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		async.processReminder(entry)

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done")
			self.assertIn("Nice!", self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertTrue(entry.hidden)

	# Make sure we create a new entry instead of a followup
	def test_create_new_after_reminder(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		firstEntry = Entry.objects.filter(label="#reminders").last()

		# Make sure the snooze tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(firstEntry)
			self.assertIn("let me know when you're done", self.getOutput(mock))

		# Make sure we create a new entry and don't treat as a followup
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to go biking this weekend")
			self.assertIn("Sat", self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		secondEntry = Entry.objects.filter(label="#reminders").last()
		self.assertNotEqual(firstEntry.id, secondEntry.id)

	# Test fuzzy matching to a single world
	def test_done_fuzzy_one_word_match(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "buy that thing I need tomorrow")
		cliMsg.msg(self.testPhoneNumber, "send email to alex tomorrow")
		cliMsg.msg(self.testPhoneNumber, "poop in the woods tomorrow")

		cliMsg.msg(self.testPhoneNumber, "done with email")

		entry = Entry.objects.get(text="send email to alex")
		days, hours = time_utils.daysAndHoursAgo(entry.remind_timestamp)
		self.assertTrue(entry.hidden)

	# Test fuzzy matching to a single world
	def test_snooze_fuzzy_one_word_match(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "buy that thing I need tomorrow")
		cliMsg.msg(self.testPhoneNumber, "send email to alex tomorrow")
		cliMsg.msg(self.testPhoneNumber, "poop in the woods tomorrow")

		cliMsg.msg(self.testPhoneNumber, "snooze email for 1 week")

		entry = Entry.objects.get(text="send email to alex")
		dt = entry.remind_timestamp - date_util.now()
		self.assertTrue(dt.days == 7, "Days != 7.  Days == %d, Today: %s Remind TS %s" % (dt.days, date_util.now(), entry.remind_timestamp))

	# Make that after we send a reminder, we eventually look for a fuzzy match
	def test_reminder_sent_fuzzy_match_default(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "Remind me to call mom tomorrow")
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 10 minutes")

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		async.processReminder(entry)

		# Now make sure if we type done, we get a nice response and it gets hidden
		cliMsg.msg(self.testPhoneNumber, "Done with call mom")

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").first()
		self.assertTrue(entry.hidden)

	# Make sure that when there's two reminders, if we just sent a reminder and there's no
	# fuzzy match, we use that one
	def test_reminder_sent_fuzzy_match_not_default(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "Remind me to call mom tomorrow")
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		async.processReminder(entry)

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done!")
			# When we respond to a reminder just sent, we don't include the text
			self.assertNotIn("go poop", self.getOutput(mock))

		# Make sure the last entry was hidden
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertTrue(entry.hidden)

	# Make sure that when there's two reminders, if we just sent a reminder and there's no
	# fuzzy match, we use that one
	def test_followup_fuzzy_match(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me to call mom tomorrow")

		# Send in a message that could be new, but really is a followup
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "actually, I want to call mom on sunday")

			self.assertIn("Sun", self.getOutput(mock))

		# Make sure there's only one entry
		self.assertEqual(1, len(Entry.objects.filter(label="#reminders")))

	# Make sure we don't send a reminder if it should be included in the digest
	def test_process_skips_if_digest_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to run tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("by 9am", self.getOutput(mock))

		# Make sure it was made for Tue 9am
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals(2, entry.remind_timestamp.day)
		self.assertEquals(13, entry.remind_timestamp.hour)

		"""
		Commenting out since now we're pinging every day
		# Nothing for digest yet
		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			# We shouldn't send a digest since we have an entry for tomorrow
			self.assertEqual("", self.getOutput(mock))
		"""

		# Now set to tomorrow at 9am, when the reminder is set for
		self.setNow(dateMock, self.TUE_858AM)

		# Shouldn't send in the normal processReminders
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertEquals("", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		# Digest should kicks off
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("run", self.getOutput(mock))

	# Make sure we create a new entry instead of a followup
	def test_snooze_all_after_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad tomorrow")
		cliMsg.msg(self.testPhoneNumber, "I need to go buy some stuff this weekend")
		cliMsg.msg(self.testPhoneNumber, "I need to go poop in the yard tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("run with your dad", self.getOutput(mock))
			self.assertIn("go poop in the yard", self.getOutput(mock))
			self.assertNotIn("buy some stuff", self.getOutput(mock))

		# Digest should kicks off
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Snooze all 3 days")
			self.assertIn("I'll remind", self.getOutput(mock))

		# Make sure first and third have dates three days from now
		entries = Entry.objects.all()
		for entry in [entries[0], entries[2]]:
			dt = entry.remind_timestamp - date_util.now()
			self.assertTrue(dt.days == 3, "Days != 3.  Days == %d, Today: %s Remind TS %s" % (dt.days, date_util.now(), entry.remind_timestamp))

	def test_done_all_after_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad tomorrow")
		cliMsg.msg(self.testPhoneNumber, "I need to go buy some stuff this weekend")
		cliMsg.msg(self.testPhoneNumber, "I need to go poop in the yard tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("run with your dad", self.getOutput(mock))
			self.assertIn("go poop in the yard", self.getOutput(mock))
			self.assertNotIn("buy some stuff", self.getOutput(mock))

		# Digest should kicks off
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done with all")

			self.assertIn("Nice!", self.getOutput(mock))

			# We don't send back individals
			self.assertNotIn("poop", self.getOutput(mock))

		# Make sure first and third were cleared
		entries = Entry.objects.all()
		self.assertTrue(entries[0].hidden)
		self.assertFalse(entries[1].hidden)
		self.assertTrue(entries[2].hidden)

	def test_wierd_done_msg(self, dateMock):
		self.setupUser(dateMock)

		phrases = ["Check off list", "Tasks done already", "I already did. Thanks Keeper!", "Done with that", "Got it done"]

		for donePhrase in phrases:
			self.setNow(dateMock, self.MON_8AM)
			cliMsg.msg(self.testPhoneNumber, "I need to run with my dad tomorrow")

			self.setNow(dateMock, self.TUE_9AM)
			async.processDailyDigest()

			# Digest should kicks off
			with patch('smskeeper.sms_util.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, donePhrase)

				self.assertIn("Nice!", self.getOutput(mock), donePhrase)

			# Make sure first and third were cleared
			entry = Entry.objects.last()
			self.assertTrue(entry.hidden)

	def test_check_off_done_msg(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad tomorrow")
		cliMsg.msg(self.testPhoneNumber, "I need to go buy some stuff this weekend")

		self.setNow(dateMock, self.TUE_9AM)
		async.processDailyDigest()

		# Digest should kicks off
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Check off run!")

			self.assertIn("Nice!", self.getOutput(mock))

		# Make sure first and third were cleared
		entries = Entry.objects.all()
		self.assertTrue(entries[0].hidden)
		self.assertFalse(entries[1].hidden)

	"""
	Removing this test since we're changing the functionality
	Now a non-specific done command only looks at the most recent stuff (created or sent out)
	# Make sure we clear pending even not after daily digest
	def test_done_all_not_after_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me to call charu next week")

		self.setNow(dateMock, self.MON_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop tomorrow")

		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me dancy dance tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		cliMsg.msg(self.testPhoneNumber, "Done with everything")

		# Make sure right one is removed and not all
		entries = Entry.objects.filter(label="#reminders")
		self.assertFalse(entries[0].hidden)
		self.assertTrue(entries[1].hidden)
		self.assertTrue(entries[2].hidden)
	"""

	# Make sure we send instructions
	def test_instructions_after_first_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn(self.renderTextConstant(keeper_constants.REMINDER_DIGEST_INSTRUCTIONS), self.getOutput(mock))

		# make sure it only goes out once
		self.setNow(dateMock, self.WED_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn(self.renderTextConstant(keeper_constants.REMINDER_DIGEST_INSTRUCTIONS), self.getOutput(mock))

	# Make sure we ping the user if we don't have anything for this week
	def test_daily_digest_pings_if_nothing_set_week(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn(emoji.emojize(keeper_constants.REMINDER_DIGEST_EMPTY[0]), self.getOutput(mock))

	# Make sure we ping the user if we don't have anything for this week
	def test_daily_digest_pings_if_nothing_set_weekend(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.FRI_9AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn(emoji.emojize(keeper_constants.REMINDER_DIGEST_EMPTY[4]), self.getOutput(mock))

	# Make sure we don't ping for product id 0
	def test_daily_digest_doesnt_ping_product_0(self, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.product_id = keeper_constants.REMINDER_PRODUCT_ID
		user.save()

		self.setNow(dateMock, self.MON_9AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("", self.getOutput(mock))

	# Make sure we ping the user if we don't have anything for this week, but we do for this weekend
	def test_daily_digest_pings_if_weekend_set(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop this weekend")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn(emoji.emojize(keeper_constants.REMINDER_DIGEST_EMPTY[0]), self.getOutput(mock))

	"""
	Commenting out since now we're pinging every day
	# Make sure we don't ping if we have something for the week
	def test_daily_digest_doesnt_ping_if_something_set(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop wednesday")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertEqual("", self.getOutput(mock))


	# Make sure we don't ping if we have something for the week
	def test_daily_digest_doesnt_ping_if_not_right_day(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.WED_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop Thursday")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertEqual("", self.getOutput(mock))
	"""

	# Make sure we create a new entry instead of a followup
	def test_stop_then_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Stop")
			self.assertIn("I won't", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertEqual("", self.getOutput(mock))

		self.setNow(dateMock, self.WED_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertEqual("", self.getOutput(mock))

	def test_clean_up_text(self, dateMock):
		self.setupUser(dateMock)
		self.setNow(dateMock, self.TUE_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "take brick to the vet on Friday at 3:45.")
			self.assertIn("Fri", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual(entry.text, "take brick to the vet")

	def test_can_you(self, dateMock):
		self.setupUser(dateMock)
		self.setNow(dateMock, self.TUE_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "can you remind me on monday to get a resume?")
			self.assertIn("Mon", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual(entry.text, "get a resume")

	# Make sure we fuzzy match after taking out the done with.
	# If we didn't, then this test would fail
	def test_reminder_removes_done_with_after(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me to call charu tomorrow")

		self.setNow(dateMock, self.MON_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("call charu", self.getOutput(mock))
			self.assertIn("go poop", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done with charu")
			self.assertIn("Nice", self.getOutput(mock))

		# Make sure right one is removed and not all
		entries = Entry.objects.filter(label="#reminders")
		self.assertTrue(entries[0].hidden)
		self.assertFalse(entries[1].hidden)

	# Make sure we fuzzy match after taking out the done with.
	# If we didn't, then this test would fail
	def test_done_with_and(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me to call charu tomorrow")

		self.setNow(dateMock, self.MON_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop tomorrow")

		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me dancy dance tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		async.processDailyDigest()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done with charu and poop")
			self.assertIn("Nice", self.getOutput(mock))

		# Make sure right ones are removed and not all
		entries = Entry.objects.filter(label="#reminders")
		self.assertTrue(entries[0].hidden)
		self.assertTrue(entries[1].hidden)
		self.assertFalse(entries[2].hidden)

	# Make sure we can handle messages that have and in it and its not meant to be split
	def test_done_with_and_not_split(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "Find house tomorrow")
		cliMsg.msg(self.testPhoneNumber, "message Amina and dazie tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		async.processDailyDigest()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done with message Amina and dazie")
			self.assertIn("Nice", self.getOutput(mock))
			self.assertNotIn("I'm not sure which entry you mean", self.getOutput(mock))

		# Make sure we hid the entry
		entries = Entry.objects.filter(label="#reminders")
		self.assertFalse(entries[0].hidden)
		self.assertTrue(entries[1].hidden)

		self.assertFalse(self.getTestUser().paused)

	# Make sure we pause after an unknown phrase
	def test_done_unknown_pauses(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me to call charu next week")
		self.setNow(dateMock, self.MON_9AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop tomorrow")
		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me dancy dance tomorrow")

		self.setNow(dateMock, self.TUE_3PM)

		# Some unkown phrase, we shouldn't get anything back
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done with the other thing")
			self.assertEquals("", self.getOutput(mock))

		# Make sure nothing was hidden
		entries = Entry.objects.filter(label="#reminders")
		self.assertFalse(entries[0].hidden)
		self.assertFalse(entries[1].hidden)
		self.assertFalse(entries[2].hidden)

		# Makae sure we're now paused
		self.assertTrue(self.getTestUser().paused)

	# Make sure we pause after an unknown phrase during daytime hours
	def test_create_unknown_pauses(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		# Some unkown phrase, we shouldn't get anything back
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "this is a random phrase")
			self.assertEquals("", self.getOutput(mock))

		# Make sure nothing was hidden
		self.assertEqual(0, len(Entry.objects.filter(label="#reminders")))

		# Makae sure we're now paused
		self.assertTrue(self.getTestUser().paused)

	# Make sure we pause after an unknown phrase during daytime hours
	def test_pauses_when_user_frustrated(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "buy stuff tomorrow")

		# Some unkown phrase, we shouldn't get anything back
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "don't do that, do later today")
			self.assertEquals("", self.getOutput(mock))

		# Makae sure we're now paused
		self.assertTrue(self.getTestUser().paused)

	# Make sure we do a create for an unkonwn phrase if its early (8 am)
	def test_create_unknown_night_creates(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		# Some unkown phrase, we shouldn't get anything back
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "this is a random phrase")
			self.assertIn("tomorrow", self.getOutput(mock))

		# Make sure nothing was hidden
		self.assertEqual(1, len(Entry.objects.filter(label="#reminders")))

		# Makae sure we're now paused
		self.assertFalse(self.getTestUser().paused)

	# Make sure we fuzzy match after taking out the done with.
	# If we didn't, then this test would fail
	def test_not_real_followup(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "Remind me to call charu tomorrow")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "nothing blah")
			self.assertEqual("", self.getOutput(mock))

	# Make sure if we type "in an hour" after it thinks its another day, it picks same day
	def test_in_an_hour(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "clean room tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "in an hour")
			self.assertIn("later today by 11am", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(1, len(entries))
		self.assertEquals(self.MON_11AM.day, entries[0].remind_timestamp.day)
		self.assertEquals(self.MON_11AM.hour, entries[0].remind_timestamp.hour)

	# Make sure if we type "tonight" after it thinks its another day, it picks same day
	def test_tonight(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "clean room tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "do tonight")
			self.assertIn("later today by 8pm", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(1, len(entries))
		self.assertEquals(self.MON_8PM.day, entries[0].remind_timestamp.day)
		self.assertEquals(self.MON_8PM.hour, entries[0].remind_timestamp.hour)

	# Make sure if we type "today" when its in the morning, it doesn't pick a time in the past
	def test_later_today(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "clean room tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "later today")
			self.assertIn("later today by 6pm", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(1, len(entries))
		self.assertEquals(22, entries[0].remind_timestamp.hour)

	# Make sure that digest pings doesn't go out for suspended users
	def test_suspended(self, dateMock):
		self.setupUser(dateMock)

		# Nothing for digest if we're suspended
		# Also make sure an incoming message brings us back
		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			# We shouldn't send a digest since we have an entry for tomorrow
			self.assertIn(emoji.emojize(keeper_constants.REMINDER_DIGEST_EMPTY[0]), self.getOutput(mock))

		self.getTestUser().setState(keeper_constants.STATE_SUSPENDED)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			# We shouldn't send a digest since we have an entry for tomorrow
			self.assertEqual("", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to go poop")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertEqual(self.getTestUser().state, keeper_constants.STATE_REMIND)

	# Hit a bug where we were running the actions.done code twice, so extra entries
	# could be cleared by accident
	def test_two_similar_entries_only_one_cleared(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)

		cliMsg.msg(self.testPhoneNumber, "write imaging doc tomorrow")

		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "send imaging doc to Thomas Hensley tomorrow")
		self.assertEqual(2, len(Entry.objects.filter(label="#reminders")))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "done writing imaging doc")
			self.assertIn("Nice!", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertTrue(entries[0].hidden)
		self.assertFalse(entries[1].hidden)

	# Hit a bug where we didn't see this was a done command and got caught in the done
	# state paused
	def test_done_command_unknown_then_real_done(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)

		cliMsg.msg(self.testPhoneNumber, "Tell Brandon you didn't get his email tomorrow")
		cliMsg.msg(self.testPhoneNumber, "write check for guymon heat and air wednesday")

		# Process another entry
		entry = Entry.objects.filter(label="#reminders").last()
		async.processReminder(entry)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Told Brandon about email")
			self.assertEquals("", self.getOutput(mock))
			self.assertTrue(self.getTestUser().paused)

		user = self.getTestUser()
		user.paused = False
		user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "done with brandon email")
			self.assertIn("Nice!", self.getOutput(mock))
			self.assertFalse(self.getTestUser().paused)

		entries = Entry.objects.filter(label="#reminders")
		self.assertTrue(entries[0].hidden)

	# Hit bug where if "done" was in a message but it was really a new entry, we barfed
	def test_remind_override_done(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to get my nails done tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

	# Hit bug where if "done" was in a message but it was really a new entry, we barfed
	def test_digest_fetch(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)

		cliMsg.msg(self.testPhoneNumber, "Tell Brandon you didn't get his email tomorrow")
		cliMsg.msg(self.testPhoneNumber, "write check for guymon heat and air today")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tasks")
			self.assertIn("Brandon", self.getOutput(mock))
			self.assertIn("guymon", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tasks for today")
			self.assertNotIn("Brandon", self.getOutput(mock))
			self.assertIn("guymon", self.getOutput(mock))

	def test_done_only_affects_last_created(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "I want to pick up my sox tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		async.processDailyDigest()

		cliMsg.msg(self.testPhoneNumber, "I need to buy tickets next week")

		cliMsg.msg(self.testPhoneNumber, "Done with that")

		entries = Entry.objects.filter(label="#reminders")

		self.assertFalse(entries[0].hidden)
		self.assertTrue(entries[1].hidden)

	def test_stop_classification(self, dateMock):
		phrase1 = "Please stop texting me"
		phrase2 = "please stop texting me!"  # Slightly different
		self.setupUser(dateMock)

		self.setNow(dateMock, self.TUE_9AM)

		# Come up with new "stop" phrase
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, phrase1)
			self.assertEqual("", self.getOutput(mock))

		# Make sure we barfed
		user = self.getTestUser()
		self.assertTrue(user.paused)

		message = Message.objects.get(msg_json__contains=phrase1)
		message.classification = "stop"
		message.save()

		user.paused = False
		user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, phrase2)
			self.assertIn("I won't", self.getOutput(mock))

		user = self.getTestUser()
		self.assertEqual(keeper_constants.STATE_STOPPED, user.state)
		self.assertFalse(user.paused)

	def test_done_classification(self, dateMock):
		phrase1 = "done and done"
		phrase2 = "done and done!"  # Slightly different
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "I want to pick up my sox tomorrow")

		self.setNow(dateMock, self.TUE_9AM)
		async.processDailyDigest()

		# Come up with new "done" phrase
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, phrase1)
			self.assertEquals("", self.getOutput(mock))

		# Make sure we barfed
		entries = Entry.objects.filter(label="#reminders")
		self.assertFalse(entries[0].hidden)
		user = self.getTestUser()
		self.assertTrue(user.paused)

		message = Message.objects.get(msg_json__contains=phrase1)
		message.classification = keeper_constants.CLASS_COMPLETE_TODO_ALL
		message.save()

		user.paused = False
		user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, phrase2)
			self.assertIn("Nice", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertTrue(entries[0].hidden)
		self.assertFalse(user.paused)

	def test_record_auto_classification(self, dateMock):
		self.setupUser(dateMock)
		messagesToTest = [
			{
				"message": "remind me to test classification in 1 hour",
				"classification": keeper_constants.CLASS_CREATE_TODO
			},
			{
				"message": "snooze test classification 2 hours",
				"classification": keeper_constants.CLASS_SNOOZE
			},
			{
				"message": "done with test classification",
				"classification": keeper_constants.CLASS_COMPLETE_TODO_SPECIFIC
			},
			{
				"message": "what is the weather",
				"classification": keeper_constants.CLASS_FETCH_WEATHER
			},
			{
				"message": "todos",
				"classification": keeper_constants.CLASS_FETCH_DIGEST
			},
			{
				"message": "ok",
				"classification": keeper_constants.CLASS_SILENT_NICETY
			},
			{
				"message": "hi",
				"classification": keeper_constants.CLASS_NICETY
			},
		]

		for i, message in enumerate(messagesToTest):
			cliMsg.msg(self.testPhoneNumber, message["message"])
			messages = self.user.getMessages(incoming=True)
			self.assertEquals(messages[i].auto_classification, message["classification"])

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
			self.assertIn("wake up", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("wake up", self.getOutput(mock))

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
			self.assertIn("wake up", self.getOutput(mock))

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
			self.assertIn("wake up", self.getOutput(mock))

		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(weeks=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

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
			self.assertIn("wake up", self.getOutput(mock))

		# Should be in the digest
		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("wake up", self.getOutput(mock))

		# Should be sent out at 10 am
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

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
			self.assertIn("wake up", self.getOutput(mock))

		# Should be sent out at 10 am Tue
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=1))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("wake up", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertTrue(entry.hidden)

		# Now that its Wed, it shouldn't go out
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=2))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertEqual("", self.getOutput(mock))

	# Pretend that the async processing didn't mark something as hidden.
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
			self.assertIn("wake up", self.getOutput(mock))

		# Explicitly don't run the job on Tuesday
		entry = Entry.objects.get(label="#reminders")
		self.assertFalse(entry.hidden)

		# Now that its Wed, it shouldn't go out
		self.setNow(dateMock, self.MON_10AM + datetime.timedelta(days=2))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertEqual("", self.getOutput(mock))

	weatherData = {'html_description': u'\n<img src="http://l.yimg.com/a/i/us/we/52/26.gif"/><br />\n<b>Current Conditions:</b><br />\nCloudy, 78 F<BR />\n<BR /><b>Forecast:</b><BR />\nTue - Scattered Thunderstorms. High: 82 Low: 75<br />\nWed - PM Thunderstorms. High: 83 Low: 66<br />\nThu - Partly Cloudy. High: 83 Low: 67<br />\nFri - Mostly Sunny. High: 82 Low: 69<br />\nSat - Partly Cloudy. High: 84 Low: 73<br />\n<br />\n<a href="http://us.rd.yahoo.com/dailynews/rss/weather/New_York__NY/*http://weather.yahoo.com/forecast/USNY0996_f.html">Full Forecast at Yahoo! Weather</a><BR/><BR/>\n(provided by <a href="http://www.weather.com" >The Weather Channel</a>)<br/>\n', 'atmosphere': {'pressure': u'29.7', 'rising': u'2', 'visibility': u'10', 'humidity': u'66'}, 'title': u'Yahoo! Weather - New York, NY', 'condition': {'date': u'Tue, 14 Jul 2015 11:49 am EDT', 'text': u'Cloudy', 'code': u'26', 'temp': u'78', 'title': u'Conditions for New York, NY at 11:49 am EDT'},
					'forecasts': [
						{'code': u'38', 'text': u'Scattered Thunderstorms', 'high': u'82', 'low': u'75', 'date': u'14 Jul 2015', 'day': u'Tue'},
						{'code': u'38', 'text': u'PM Thunderstorms', 'high': u'83', 'low': u'66', 'date': u'15 Jul 2015', 'day': u'Wed'},
						{'code': u'30', 'text': u'Partly Cloudy', 'high': u'83', 'low': u'67', 'date': u'16 Jul 2015', 'day': u'Thu'},
						{'code': u'34', 'text': u'Mostly Sunny', 'high': u'82', 'low': u'69', 'date': u'17 Jul 2015', 'day': u'Fri'},
						{'code': u'30', 'text': u'Partly Cloudy', 'high': u'84', 'low': u'73', 'date': u'18 Jul 2015', 'day': u'Sat'}],
					'link': u'http://us.rd.yahoo.com/dailynews/rss/weather/New_York__NY/*http://weather.yahoo.com/forecast/USNY0996_f.html', 'location': {'city': u'New York', 'region': u'NY', 'country': u'US'}, 'units': {'distance': u'mi', 'speed': u'mph', 'temperature': u'F', 'pressure': u'in'}, 'astronomy': {'sunset': u'8:25 pm', 'sunrise': u'5:33 am'}, 'geo': {'lat': u'40.67', 'long': u'-73.94'}, 'wind': {'direction': u'150', 'speed': u'3', 'chill': u'78'}}

	@patch('common.weather_util.getWeatherForZip')
	def test_weather_in_digest(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.zipcode = "10012"
		user.save()

		weatherMock.return_value = self.weatherData

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("forecast: Scattered Thunderstorms", self.getOutput(mock))

	@patch('common.weather_util.getWeatherForZip')
	def test_weather_not_in_requested_digest(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.zipcode = "10012"
		user.save()

		weatherMock.return_value = self.weatherData

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tasks")
			self.assertNotIn("forecast:", self.getOutput(mock))
			self.assertIn(keeper_constants.REMINDER_DIGEST_EMPTY[0], self.getOutput(mock))

	@patch('common.weather_util.getWeatherForZip')
	def test_weather_on_request(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.zipcode = "10012"
		user.save()

		weatherMock.return_value = self.weatherData

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "what is the weather?")
			self.assertIn("forecast: Scattered Thunderstorms", self.getOutput(mock))

	@patch('common.weather_util.getWeatherForZip')
	def test_weather_on_request_tomorrow(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.zipcode = "10012"
		user.save()

		weatherMock.return_value = self.weatherData

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "what is the weather tomorrow?")
			self.assertIn("Wednesday's forecast: PM Thunderstorms", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "what is the weather Thursday?")
			self.assertIn("Thursday's forecast: Partly Cloudy", self.getOutput(mock))

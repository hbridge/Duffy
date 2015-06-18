import datetime

from mock import patch

from smskeeper import cliMsg, async
from smskeeper.models import Entry

import test_base


@patch('common.date_util.utcnow')
class SMSKeeperTodoCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, dateMock):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		super(SMSKeeperTodoCase, self).setupUser(True, True, productId=1)

	def test_no_time(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to run")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("by 9am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals(13, entry.remind_timestamp.hour)  # 9 am EST

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
		self.assertEquals("you need to pick up your sox", entry.text)

	def test_two_entries(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I want to pick up my sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		firstEntry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals("you want to pick up your sox", firstEntry.text)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to buy tickets next week")
			self.assertIn("Mon", self.getOutput(mock))

		secondEntry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals("you need to buy tickets", secondEntry.text)

		self.assertNotEqual(firstEntry.id, secondEntry.id)

	def test_weekend_no_time(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to buy detergent this weekend")
			if (datetime.datetime.now(self.getTestUser().getTimezone()).weekday() == 4):  # Its Friday, so check for tmr
				self.assertIn("tomorrow", self.getOutput(mock))
			else:
				self.assertIn("Sat", self.getOutput(mock))
			self.assertNotIn("9 am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals("you need to buy detergent", entry.text)

	def test_weekend_with_time(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to prep dinner sat at 5 pm")
			if (datetime.datetime.now(self.getTestUser().getTimezone()).weekday() == 4):  # Its Friday, so check for tmr
				self.assertIn("tomorrow", self.getOutput(mock))
			else:
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
		cliMsg.msg(self.testPhoneNumber, "I need to buy sox in 1 minute")

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

		cliMsg.msg(self.testPhoneNumber, "text dan")
		cliMsg.msg(self.testPhoneNumber, "call court")

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

	# Make sure first reminder we send snooze tip, then second we don't
	def test_done_fuzzy_one_word_match(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "buy that thing I need")
		cliMsg.msg(self.testPhoneNumber, "send email to alex")
		cliMsg.msg(self.testPhoneNumber, "poop in the woods")

		cliMsg.msg(self.testPhoneNumber, "done with email")

		entry = Entry.objects.get(text="send email to alex")
		self.assertTrue(entry.hidden)

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

	# Make sure we create a new entry instead of a followup
	def test_process_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to run")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("by 9am", self.getOutput(mock))

		# Make sure it was made for Tue 9am
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals(2, entry.remind_timestamp.day)
		self.assertEquals(13, entry.remind_timestamp.hour)

		# Nothing for digest yet
		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest("test")
			self.assertEquals("fyi, there's nothing I'm tracking for you today. If something comes up, txt me", self.getOutput(mock))

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
			self.assertIn("you need to run", self.getOutput(mock))

	# Make sure we create a new entry instead of a followup
	def test_done_all_after_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad")
		cliMsg.msg(self.testPhoneNumber, "I need to go buy some stuff this weekend")
		cliMsg.msg(self.testPhoneNumber, "I need to go poop in the yard")

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

	# Make sure we clear pending even not after daily digest
	def test_done_all_not_after_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me to call charu next week")
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop tomorrow")
		cliMsg.msg(self.testPhoneNumber, "Remind me dancy dance tomorrow")

		self.setNow(dateMock, self.TUE_9AM)

		cliMsg.msg(self.testPhoneNumber, "Done with everything")

		# Make sure right one is removed and not all
		entries = Entry.objects.filter(label="#reminders")
		self.assertFalse(entries[0].hidden)
		self.assertTrue(entries[1].hidden)
		self.assertTrue(entries[2].hidden)

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
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop tomorrow")
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

	# Make sure we pause after an unknown phrase
	def test_done_unknown_pauses(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me to call charu next week")
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop tomorrow")
		cliMsg.msg(self.testPhoneNumber, "Remind me dancy dance tomorrow")

		self.setNow(dateMock, self.TUE_3PM)

		# Some unkown phrasem, we shouldn't get anything back
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



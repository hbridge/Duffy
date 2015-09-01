# -*- coding: utf-8 -*-

import datetime
from mock import patch
import logging

from smskeeper import cliMsg, async, keeper_constants, tips
from smskeeper.models import Entry, Message

import test_base

import emoji
from smskeeper import time_utils
from common import date_util
from datetime import timedelta

logger = logging.getLogger()
logger.level = logging.DEBUG


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
		self.assertEquals("Pick up your sox", entry.text)

	def test_two_entries(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I want to pick up my sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		self.setNow(dateMock, self.mockedDate + timedelta(hours=1))  # prevent squashing
		firstEntry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals("Pick up your sox", firstEntry.text)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to buy tickets next week")
			self.assertIn("Mon", self.getOutput(mock))

		secondEntry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals("Buy tickets", secondEntry.text)

		self.assertNotEqual(firstEntry.id, secondEntry.id)

	def test_weekend_no_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to buy detergent this weekend")
			self.assertIn("Sat", self.getOutput(mock))
			self.assertNotIn("9 am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals("Buy detergent", entry.text)

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
			self.assertIn("today by 11pm", self.getOutput(mock))

	def test_done_hides(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.get(label="#reminders")

		# Make sure the done tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)

			foundMiniTip = False
			for tip in tips.DONE_MINI_TIPS_LIST:
				if tip.message in self.getOutput(mock):
					foundMiniTip = True
			self.assertTrue(foundMiniTip, self.getOutput(mock))

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done!")
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertTrue(entry.hidden)

	# Make sure the quetion tip goes out after 7
	def test_digest_survey_tip(self, dateMock):
		self.setupUser(dateMock)

		user = self.getTestUser()
		user.added = self.MON_8AM
		user.save()

		self.setNow(dateMock, self.MON_8AM)

		# Add a message and make it look like it was sent at the right time
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop")
		message = Message.objects.get(id=1)
		message.added = self.MON_8AM
		message.save()

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("how useful", self.getOutput(mock))
			self.assertIn("sunshine", self.getOutput(mock))

		# 5 days later to ckick off the first tip
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=5))
		async.processDailyDigest()

		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=7))

		# Make sure the survey tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("how useful", self.getOutput(mock))

		# Make sure a response doesn't kick off anything
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "4")
			self.assertIn("Great to hear!", self.getOutput(mock))

	# Make sure the digest survey question changes state if its a low answer
	def test_digest_survey_answer_changes_digest_state(self, dateMock):
		self.setupUser(dateMock)

		user = self.getTestUser()
		user.added = self.MON_8AM
		user.save()

		self.setNow(dateMock, self.MON_8AM)

		# Add a message and make it look like it was sent at the right time
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop")
		message = Message.objects.get(id=1)
		message.added = self.MON_8AM
		message.save()

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("how useful", self.getOutput(mock))
			self.assertIn("sunshine", self.getOutput(mock))

		# 5 days later
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=5))

		# Make sure the change time tip comes through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("a good time for this?", self.getOutput(mock))

		# 7 days later from original
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=7))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("how useful", self.getOutput(mock))

		# Make sure a response doesn't kick off anything
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "2")
			self.assertIn("Got it, I won't", self.getOutput(mock))

		user = self.getTestUser()
		self.assertEqual(user.digest_state, keeper_constants.DIGEST_STATE_LIMITED)

	# Had bug where we weren't catching survey numbers when there were no tasks
	def test_digest_survey_tip_no_tasks(self, dateMock):
		self.setupUser(dateMock)

		user = self.getTestUser()
		user.added = self.MON_8AM
		user.save()

		self.setNow(dateMock, self.MON_8AM)

		# Add a message and make it look like it was sent at the right time
		cliMsg.msg(self.testPhoneNumber, "Remind me go poop")
		message = Message.objects.get(id=1)
		message.added = self.MON_8AM
		message.save()
		cliMsg.msg(self.testPhoneNumber, "done")
		message = Message.objects.filter(incoming=True).order_by('added').last()
		message.added = self.MON_8AM
		message.save()

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("how useful", self.getOutput(mock))
			self.assertIn("sunshine", self.getOutput(mock))

		# 5 days later
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=5))
		async.processDailyDigest()

		# 7 days later
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=7))

		# Make sure the snooze tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("how useful", self.getOutput(mock))

		# Make sure a response doesn't kick off anything
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "4")
			self.assertIn("Great to hear!", self.getOutput(mock))


	"""
	Commenting out since we removed this for now
	# Make sure the quetion tip goes out after 7
	def test_digest_nps(self, dateMock):
		self.setupUser(dateMock)

		user = self.getTestUser()
		user.added = self.MON_8AM
		user.save()

		self.setNow(dateMock, self.MON_8AM)
		# 5 days later to ckick off the first tip
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=5))
		async.processDailyDigest()

		# 2 more days to do next tip
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=7))
		async.processDailyDigest()

		# 2 more days to do next tip
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=9))

		# Make sure the survey tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("recommend me", self.getOutput(mock))

		# Make sure a response doesn't kick off anything
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "5")
			self.assertIn("Got it.", self.getOutput(mock))
	"""


	# Make sure the change digest time goes out after 5 days, and it changes the time
	def test_digest_tips_change_time(self, dateMock):
		self.setupUser(dateMock)

		user = self.getTestUser()
		user.added = self.MON_8AM
		user.save()

		# Set for 4 days in future
		self.setNow(dateMock, self.FRI_9AM)

		cliMsg.msg(self.testPhoneNumber, "Go poop at 3pm today")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("is 9am a good time for this", self.getOutput(mock))

		# Set for 5 days in future
		self.setNow(dateMock, self.SAT_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("is 9am a good time for this", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "6")
			self.assertIn("daily summary at 6am", self.getOutput(mock))

		self.assertEqual(6, self.getTestUser().digest_hour)
		self.assertEqual(0, self.getTestUser().digest_minute)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "actually, 2:30pm please")
			self.assertIn("daily summary at 2:30pm", self.getOutput(mock))

		self.assertEqual(14, self.getTestUser().digest_hour)
		self.assertEqual(30, self.getTestUser().digest_minute)

	# Make sure we support things like "stop sending me these" and "never"
	def test_digest_tips_change_time_supports_never(self, dateMock):
		self.setupUser(dateMock)

		user = self.getTestUser()
		user.added = self.MON_8AM
		user.save()

		# Set for 5 days in future
		self.setNow(dateMock, self.SAT_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("is 9am a good time for this", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "never")
			self.assertIn("I won't", self.getOutput(mock))

		self.assertEqual(self.getTestUser().digest_state, keeper_constants.DIGEST_STATE_LIMITED)

	# Make sure we support things like "stop sending me these" and "never"
	def test_digest_tips_change_time_doesnt_superceed_create(self, dateMock):
		self.setupUser(dateMock)

		user = self.getTestUser()
		user.added = self.MON_8AM
		user.save()

		# Set for 5 days in future
		self.setNow(dateMock, self.SAT_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("is 9am a good time for this", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to go poop at 3pm")
			self.assertIn("by 3pm", self.getOutput(mock))
			self.assertNotIn("summary", self.getOutput(mock))

		self.assertEqual(self.getTestUser().digest_hour, 9)


	# Had a bug where just 'remind me' would create an entry
	def test_just_remind_me(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me?")
			self.assertEqual("", self.getOutput(mock))

	def test_joke_normal(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I dunno, what")
			self.assertEqual("A stick", self.getOutput(mock))

	# Make sure if they don't answer, we end up back in normal state
	def test_joke_no_answer(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to poop in an hour")
			self.assertIn("by 11am", self.getOutput(mock))

		user = self.getTestUser()
		self.assertEqual(user.state, keeper_constants.STATE_NORMAL)

	# Make sure if they don't answer, we end up back in normal state
	def test_joke_correct_answer(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "A stick!")
			self.assertIn("yup!", self.getOutput(mock))

	def test_joke_with_laugh(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I dunno, what")
			self.assertEqual("A stick", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "haha, nice!")
			self.assertEqual(u'\U0001f60e', self.getOutput(mock))

	def test_joke_with_badjoke(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I dunno, what")
			self.assertEqual("A stick", self.getOutput(mock))

		# make sure they get their pony
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "that was a terrible joke")
			self.assertIn(u'\U0001F434', self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "i didn't laugh. Where's my pony?")
			self.assertIn(u'\U0001F434', self.getOutput(mock))

	def test_joke_with_laugh_and_followup(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I dunno, what")
			self.assertEqual("A stick", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "haha, nice!")
			self.assertEqual(u'\U0001f60e', self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "blah blah blah")
			self.assertEqual('', self.getOutput(mock))

		self.assertTrue(self.getTestUser().paused)

	def test_joke_runs_out(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I dunno, what")
			self.assertEqual("A stick", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "haha, nice!")
			self.assertEqual(u'\U0001f60e', self.getOutput(mock))

		# Make it like we ran out of jokes
		user = self.getTestUser()
		user.setStateData("joke-num", 1000)

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertIn("all out", self.getOutput(mock))

	def test_joke_again_after_6_hours(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I dunno, what")
			self.assertEqual("A stick", self.getOutput(mock))

		# make sure we get 2 jokes a day, this should work
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "another")
			self.assertEqual("What do you call two banana peels?", self.getOutput(mock))

		# make sure we get 2 jokes a day, this should work
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "you tell me")
			self.assertEqual("A pair of slippers", self.getOutput(mock))

		# ask two more jokes, should have answers
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me another joke")
			cliMsg.msg(self.testPhoneNumber, "I dunno")
			cliMsg.msg(self.testPhoneNumber, "tell me another joke")
			cliMsg.msg(self.testPhoneNumber, "I dunno")
			self.assertNotIn("ask me again", self.getOutput(mock))

		# Now should be out
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me another joke")
			self.assertIn("ask me again", self.getOutput(mock))

		# later that night...
		self.setNow(dateMock, self.MON_10PM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me another joke please")
			self.assertNotEqual("", self.getOutput(mock))
			self.assertNotIn("ask me again", self.getOutput(mock))

	def test_joke_then_reminder(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me a joke")
			self.assertEqual("What do you call a boomerang that doesn't come back?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I dunno, what")
			self.assertEqual("A stick", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hehe, nice")
			self.assertEqual(u'\U0001f60e', self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "haha, ok, please wake me up tomorrow at 8:30")
			self.assertIn("by 8:30am", self.getOutput(mock))

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
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

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
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertTrue(entry.hidden)

	"""
	def test_remind_me_again(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "text dan tomorrow at 10am")

		self.setNow(dateMock, self.TUE_10AM)
		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Text dan", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me again")
			self.assertIn("tomorrow", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me today")
			self.assertIn("9pm", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me in an hour")
			self.assertIn("by 11am", self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(1, len(entries))
	"""

	# Checks to make sure we can mark things as done even if they're not in the regex
	# This assumes "blah" is a real verb but not in the regex
	def test_fuzzy_match_done_specific_non_regex(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "Go blah Tonya saturday")
		cliMsg.msg(self.testPhoneNumber, "call court on the phone tomorrow")

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I blahed tonya")
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").first()
		self.assertTrue(entry.hidden)

	# Make sure we create entries that start with a whitelisted "create" term
	def test_whitelist_create_no_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "print shit out")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertIn(keeper_constants.FOLLOWUP_TIME_TEXT, self.getOutput(mock))

	# Make sure we create a new entry instead of a followup
	def test_create_new_after_reminder(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop in 1 minute")

		# Now make it process the record, like the reminder fired
		firstEntry = Entry.objects.filter(label="#reminders").last()

		# Make sure the done tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(firstEntry)
			foundMiniTip = False
			for tip in tips.DONE_MINI_TIPS_LIST:
				if tip.message in self.getOutput(mock):
					foundMiniTip = True
			self.assertTrue(foundMiniTip, self.getOutput(mock))

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

		entry = Entry.objects.get(text="Send email to alex")
		days, hours = time_utils.daysAndHoursAgo(entry.remind_timestamp)
		self.assertTrue(entry.hidden)

	# Test fuzzy matching to a single world
	def test_snooze_fuzzy_one_word_match(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "buy that thing I need tomorrow")
		cliMsg.msg(self.testPhoneNumber, "send email to alex tomorrow")
		cliMsg.msg(self.testPhoneNumber, "poop in the woods tomorrow")

		cliMsg.msg(self.testPhoneNumber, "snooze email for 1 week")

		entry = Entry.objects.get(text="Send email to alex")
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
			self.assertNotIn("Go poop", self.getOutput(mock))

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
			self.assertIn("Run", self.getOutput(mock))

	# Make sure we don't send a digest if the user has it turned off
	def test_digest_skips_if_not_default(self, dateMock):
		self.setupUser(dateMock)

		user = self.getTestUser()
		user.digest_state = keeper_constants.DIGEST_STATE_LIMITED
		user.save()

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run tomorrow")

		self.setNow(dateMock, self.MON_9AM)
		# Digest shouldn't print for this user
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertEqual("", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		# Digest shouldn't print for this user
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Run", self.getOutput(mock))

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
			self.assertIn("Run with your dad", self.getOutput(mock))
			self.assertIn("Go poop in the yard", self.getOutput(mock))
			self.assertNotIn("Buy some stuff", self.getOutput(mock))

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
			self.assertIn("Run with your dad", self.getOutput(mock))
			self.assertIn("Go poop in the yard", self.getOutput(mock))
			self.assertNotIn("Buy some stuff", self.getOutput(mock))

		# Digest should kicks off
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done with all")

			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

			# We don't send back individals
			self.assertNotIn("Poop", self.getOutput(mock))

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

				self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock), donePhrase)

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

			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

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
	def test_instructions_after_daily_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad this afternoon")

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn(self.renderTextConstant(keeper_constants.REMINDER_DIGEST_DONE_INSTRUCTIONS), self.getOutput(mock))

		# make sure after 3 days, we now do the snooze
		self.setNow(dateMock, self.FRI_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn(self.renderTextConstant(keeper_constants.REMINDER_DIGEST_SNOOZE_INSTRUCTIONS), self.getOutput(mock))
	'''
	# Make sure we expire tasks after N days
	def test_old_tasks_fall_off_the_digest_on_Monday(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad at 2pm today")

		# trigger the reminder; this is important, otherwise remind_last_notified won't be updated
		self.setNow(dateMock, self.MON_2PM)
		async.processAllReminders()

		# task should show up
		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Run with your dad", self.getOutput(mock))

		# task should show up
		self.setNow(dateMock, self.WED_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Run with your dad", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "I need to call Mom on Monday")

		# task should show up
		self.setNow(dateMock, self.THU_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Run with your dad", self.getOutput(mock))

		# task should show up under old tasks
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=7))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Call Mom", self.getOutput(mock))
			self.assertIn("old tasks", self.getOutput(mock))
			self.assertIn("Run with your dad", self.getOutput(mock))
			self.assertIn("my.getkeeper.com/", self.getOutput(mock))

		# task shouldn't show up anymore
		self.setNow(dateMock, self.TUE_9AM + datetime.timedelta(days=7))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Call Mom", self.getOutput(mock))
			self.assertNotIn("Run with your dad", self.getOutput(mock))
			self.assertNotIn("my.getkeeper.com/", self.getOutput(mock))

	# Make sure we expire tasks after N days
	def test_old_tasks_fall_off_the_digest_for_limited_digest(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)
		user = self.getTestUser()
		user.digest_state = keeper_constants.DIGEST_STATE_LIMITED
		user.save()
		cliMsg.msg(self.testPhoneNumber, "I need to run with my dad tomorrow at 2pm")

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Run with your dad", self.getOutput(mock))

		# trigger the reminder; this is important, otherwise remind_last_notified won't be updated
		self.setNow(dateMock, self.TUE_2PM)
		async.processAllReminders()

		# digest should go out with this task under "old tasks"
		self.setNow(dateMock, self.MON_9AM + datetime.timedelta(days=7))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Run with your dad", self.getOutput(mock))
			self.assertIn("my.getkeeper.com/", self.getOutput(mock))

		# digest shouldn't go out at all
		self.setNow(dateMock, self.TUE_9AM + datetime.timedelta(days=7))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("Run with your dad", self.getOutput(mock))
	'''
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
		self.assertEqual(entry.text, "Take brick to the vet")

	def test_can_you(self, dateMock):
		self.setupUser(dateMock)
		self.setNow(dateMock, self.TUE_8AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "can you remind me on monday to get a resume?")
			self.assertIn("Mon", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEqual(entry.text, "Get a resume")

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
			self.assertIn("Call charu", self.getOutput(mock))
			self.assertIn("Go poop", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Done with charu")
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

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
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

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
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))
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
			cliMsg.msg(self.testPhoneNumber, "Done with buying sox")
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
			cliMsg.msg(self.testPhoneNumber, "don't do that, dummy")
			self.assertEquals("", self.getOutput(mock))

		# Makae sure we're now paused
		self.assertTrue(self.getTestUser().paused)

		# Make sure we pause after an unknown phrase during daytime hours
	def test_frustration_with_reminder_text(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "take medicine tomorrow")

		# Some unkown phrase, we shouldn't get anything back
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "no longer need reminder to take medicine")
			self.assertEquals("", self.getOutput(mock))

		# Makae sure we're now paused
		self.assertTrue(self.getTestUser().paused)

	# Make sure we do correction even when frustrated if there's a time in there
	def test_corrects_even_when_frustrated(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "buy stuff tomorrow")

		# Some unkown phrase, we shouldn't get anything back
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "don't do that, do later today")
			self.assertIn("later today by 6pm", self.getOutput(mock))

	# Make sure send a sleep response for an unkonwn phrase if its early (8 am)
	def test_create_unknown_night_doesnt_create(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_8AM)

		# Some unkown phrase, we shouldn't get anything back
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "this is a random phrase")
			self.assertIn(self.getOutput(mock), emoji.emojize(str(keeper_constants.UNKNOWN_COMMAND_PHRASES), use_aliases=True))

		# Make sure we didn't create anything
		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(0, len(entries))

		# Make sure we're not paused
		self.assertFalse(self.getTestUser().paused)

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
			self.assertNotEqual(self.getTestUser().state, keeper_constants.STATE_SUSPENDED)

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
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertTrue(entries[0].hidden)
		self.assertFalse(entries[1].hidden)

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

		cliMsg.msg(self.testPhoneNumber, "Remind me to tell Brandon you didn't get his email tomorrow")
		cliMsg.msg(self.testPhoneNumber, "write check for guymon heat and air today")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tasks")
			self.assertIn("Brandon", self.getOutput(mock))
			self.assertIn("guymon", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tasks for today")
			self.assertNotIn("Brandon", self.getOutput(mock))
			self.assertIn("guymon", self.getOutput(mock))

	def test_digest_fetch_overagressive(self, dateMock):
		self.setupUser(dateMock)
		msgs = [
			"need to do laundry",
			"cancel all cough syrup reminders"
		]
		for msg in msgs:
			cliMsg.msg(self.testPhoneNumber, msg)
			self.assertFalse(
				self.getTestUser().wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_DIGEST),
				"Msg: '%s' triggered digest fetch" % msg
			)
			self.getTestUser().paused = False
			self.getTestUser().save()

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

	# Make sure that when we classify a message as a completetodo then resend, it works
	def test_done_classification(self, dateMock):
		phrase1 = "done and newword"
		phrase2 = "done and newword!"  # Slightly different
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
		message.classification = keeper_constants.CLASS_COMPLETE_TODO_MOST_RECENT
		message.save()

		user.paused = False
		user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, phrase2)
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

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
				"classification": keeper_constants.CLASS_CHANGETIME_SPECIFIC
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

	weatherData = {'html_description': u'\n<img src="http://l.yimg.com/a/i/us/we/52/26.gif"/><br />\n<b>Current Conditions:</b><br />\nCloudy, 78 F<BR />\n<BR /><b>Forecast:</b><BR />\nTue - Scattered Thunderstorms. High: 82 Low: 75<br />\nWed - PM Thunderstorms. High: 83 Low: 66<br />\nThu - Partly Cloudy. High: 83 Low: 67<br />\nFri - Mostly Sunny. High: 82 Low: 69<br />\nSat - Partly Cloudy. High: 84 Low: 73<br />\n<br />\n<a href="http://us.rd.yahoo.com/dailynews/rss/weather/New_York__NY/*http://weather.yahoo.com/forecast/USNY0996_f.html">Full Forecast at Yahoo! Weather</a><BR/><BR/>\n(provided by <a href="http://www.weather.com" >The Weather Channel</a>)<br/>\n', 'atmosphere': {'pressure': u'29.7', 'rising': u'2', 'visibility': u'10', 'humidity': u'66'}, 'title': u'Yahoo! Weather - New York, NY', 'condition': {'date': u'Tue, 14 Jul 2015 11:49 am EDT', 'text': u'Cloudy', 'code': u'26', 'temp': u'78', 'title': u'Conditions for New York, NY at 11:49 am EDT'},
					'forecasts': [
						{'code': u'38', 'text': u'Scattered Thunderstorms', 'high': u'82', 'low': u'75', 'date': u'14 Jul 2015', 'day': u'Tue'},
						{'code': u'38', 'text': u'PM Thunderstorms', 'high': u'83', 'low': u'66', 'date': u'15 Jul 2015', 'day': u'Wed'},
						{'code': u'30', 'text': u'Partly Cloudy', 'high': u'83', 'low': u'67', 'date': u'16 Jul 2015', 'day': u'Thu'},
						{'code': u'34', 'text': u'Mostly Sunny', 'high': u'82', 'low': u'69', 'date': u'17 Jul 2015', 'day': u'Fri'},
						{'code': u'30', 'text': u'Partly Cloudy', 'high': u'84', 'low': u'73', 'date': u'18 Jul 2015', 'day': u'Sat'}],
					'link': u'http://us.rd.yahoo.com/dailynews/rss/weather/New_York__NY/*http://weather.yahoo.com/forecast/USNY0996_f.html', 'location': {'city': u'New York', 'region': u'NY', 'country': u'US'}, 'units': {'distance': u'mi', 'speed': u'mph', 'temperature': u'F', 'pressure': u'in'}, 'astronomy': {'sunset': u'8:25 pm', 'sunrise': u'5:33 am'}, 'geo': {'lat': u'40.67', 'long': u'-73.94'}, 'wind': {'direction': u'150', 'speed': u'3', 'chill': u'78'}}

	weatherDataMetric = {'html_description': u'\n<img src="http://l.yimg.com/a/i/us/we/52/26.gif"/><br />\n<b>Current Conditions:</b><br />\nCloudy, 25 C<BR />\n<BR /><b>Forecast:</b><BR />\nMon - Rain Late. High: 27 Low: 22<br />\nTue - Thunderstorms. High: 28 Low: 22<br />\nWed - Mostly Sunny. High: 29 Low: 19<br />\nThu - Mostly Sunny. High: 29 Low: 21<br />\nFri - Sunny. High: 31 Low: 22<br />\n<br />\n<a href="http://us.rd.yahoo.com/dailynews/rss/weather/New_York__NY/*http://weather.yahoo.com/forecast/USNY0996_c.html">Full Forecast at Yahoo! Weather</a><BR/><BR/>\n(provided by <a href="http://www.weather.com" >The Weather Channel</a>)<br/>\n', 'atmosphere': {'pressure': u'1015.9', 'rising': u'2', 'visibility': u'16.09', 'humidity': u'54'}, 'title': u'Yahoo! Weather - New York, NY', 'condition': {'date': u'Mon, 10 Aug 2015 4:50 pm EDT', 'text': u'Cloudy', 'code': u'26', 'temp': u'25', 'title': u'Conditions for New York, NY at 4:50 pm EDT'},
					'forecasts': [
						{'code': u'12', 'text': u'Rain Late', 'high': u'27', 'low': u'22', 'date': u'10 Aug 2015', 'day': u'Mon'},
						 {'code': u'4', 'text': u'Thunderstorms', 'high': u'28', 'low': u'22', 'date': u'11 Aug 2015', 'day': u'Tue'}, {'code': u'34', 'text': u'Mostly Sunny', 'high': u'29', 'low': u'19', 'date': u'12 Aug 2015', 'day': u'Wed'}, {'code': u'34', 'text': u'Mostly Sunny', 'high': u'29', 'low': u'21', 'date': u'13 Aug 2015', 'day': u'Thu'}, {'code': u'32', 'text': u'Sunny', 'high': u'31', 'low': u'22', 'date': u'14 Aug 2015', 'day': u'Fri'}], 'link': u'http://us.rd.yahoo.com/dailynews/rss/weather/New_York__NY/*http://weather.yahoo.com/forecast/USNY0996_c.html', 'location': {'city': u'New York', 'region': u'NY', 'country': u'US'}, 'units': {'distance': u'km', 'speed': u'km/h', 'temperature': u'C', 'pressure': u'mb'}, 'astronomy': {'sunset': u'8:00 pm', 'sunrise': u'5:59 am'}, 'geo': {'lat': u'40.67', 'long': u'-73.94'}, 'wind': {'direction': u'150', 'speed': u'12.87', 'chill': u'25'}}

	weatherReturnData = {"imperial": weatherData, "metric": weatherDataMetric}
	@patch('common.weather_util.getWeatherForWxCode')
	def test_weather_in_digest(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.wxcode = "10012"
		user.save()

		weatherMock.return_value = self.weatherReturnData

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("forecast: Scattered Thunderstorms", self.getOutput(mock))

	@patch('common.weather_util.getWeatherForWxCode')
	def test_weather_not_in_requested_digest(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.wxcode = "10012"
		user.save()

		weatherMock.return_value = self.weatherReturnData

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tasks")
			self.assertNotIn("forecast:", self.getOutput(mock))
			self.assertIn(keeper_constants.REMINDER_DIGEST_EMPTY[0], self.getOutput(mock))

	@patch('common.weather_util.getWeatherForWxCode')
	def test_weather_on_request(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.wxcode = "10012"
		user.save()

		weatherMock.return_value = self.weatherReturnData

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "what is the weather?")
			self.assertIn("forecast: Scattered Thunderstorms", self.getOutput(mock))

	@patch('common.weather_util.getWeatherForWxCode')
	def test_weather_metric(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.wxcode = "10012"
		user.temp_format = "metric"
		user.save()

		weatherMock.return_value = self.weatherReturnData

		self.setNow(dateMock, self.MON_10AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "what is the weather?")
			self.assertIn(u"High 27°C", self.getOutput(mock))

	@patch('common.weather_util.getWeatherForWxCode')
	def test_weather_on_request_tomorrow(self, weatherMock, dateMock):
		self.setupUser(dateMock)
		user = self.getTestUser()
		user.wxcode = "10012"
		user.save()

		weatherMock.return_value = self.weatherReturnData

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "what's the weather tomorrow?")
			self.assertIn("Wednesday's forecast: PM Thunderstorms", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "weather tomorrow afternoon")
			self.assertIn("Wednesday's forecast: PM Thunderstorms", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "whats the weather Thursday?")
			self.assertIn("Thursday's forecast: Partly Cloudy", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "what is the weather in 2 weeks?")
			self.assertIn("I don't know", self.getOutput(mock))

	# Had a bug where a done command would be preferred instead of remind
	def test_remind_doesnt_count_as_done(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.TUE_9AM)

		cliMsg.msg(self.testPhoneNumber, "remind me to go do some stuff tomorrow")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Put all the wedding stuff in my trunk and return it at 7:50 am")
			self.assertIn("tomorrow at 7:50am", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind md put sox on at 8:50 am")
			self.assertIn("tomorrow at 8:50am", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(3, len(entries))

		# Make sure first reminder we send snooze tip, then second we don't
	def test_done_with_nicety(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop at 11")

		self.setNow(dateMock, self.MON_11AM)
		# Make sure the snooze tip came through
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Go poop", self.getOutput(mock))

		# Now make sure if we type done, we get a nice response and it gets hidden
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Thank you done")
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertTrue(entry.hidden)

	# If they snooze and don't give a time, just say tomorrow with followup
	def test_snooze_no_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop at 3")

		self.setNow(dateMock, self.MON_11AM)
		# This tries it under "most recent"
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "snooze go poop")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertIn(keeper_constants.FOLLOWUP_TIME_TEXT, self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		async.processDailyDigest()

		self.setNow(dateMock, self.TUE_10AM)
		# This tries it under "specific" since we just sent the reminder
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "snooze go poop ")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertIn(keeper_constants.FOLLOWUP_TIME_TEXT, self.getOutput(mock))

	# If they type something starting with snooze, always make sure it snoozes (even if tasks is in there)
	def test_snooze_starts_with_snooze(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop at 3")

		self.setNow(dateMock, self.MON_11AM)
		# This tries it under "most recent"
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "snooze All Tasks")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertIn(keeper_constants.FOLLOWUP_TIME_TEXT, self.getOutput(mock))

		# Now make it process the record, like the reminder fired
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertTrue(entry.remind_timestamp.day, self.TUE_9AM.day)

	def test_snooze_one_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop at 3")
		entry = Entry.objects.get(label="#reminders")
		entry.remind_recur = keeper_constants.RECUR_ONE_TIME
		entry.save()

		self.setNow(dateMock, self.MON_3PM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Go poop", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")

		# Should only be one since a new reminder shouldn't have been created
		self.assertEqual(1, len(entries))
		entry = entries[0]
		self.assertFalse(entry.hidden)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "snooze 3 hours")
			self.assertIn("6pm", self.getOutput(mock))

		self.setNow(dateMock, self.MON_6PM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Go poop", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("Go poop", self.getOutput(mock))

	def test_snooze_weekly(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop at 3")
		entry = Entry.objects.get(label="#reminders")
		entry.remind_recur = keeper_constants.RECUR_WEEKLY
		entry.save()

		self.setNow(dateMock, self.MON_3PM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Go poop", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")

		# Should be 2 since a new reminder should have been created
		self.assertEqual(2, len(entries))
		entry = entries[0]
		self.assertFalse(entry.hidden)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "snooze 3 hours")
			self.assertIn("6pm", self.getOutput(mock))

		self.setNow(dateMock, self.MON_6PM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Go poop", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("Go poop", self.getOutput(mock))

		# Make sure a week later, the reminder is back at 3pm
		self.setNow(dateMock, self.MON_3PM + datetime.timedelta(days=7))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Go poop", self.getOutput(mock))

	# Make sure we can say "done" to a weekly task and the task still shows up next time
	def test_done_weekly(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Remind me go poop at 3")
		entry = Entry.objects.get(label="#reminders")
		entry.remind_recur = keeper_constants.RECUR_WEEKLY
		entry.save()

		self.setNow(dateMock, self.MON_3PM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Go poop", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "done go poop")
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertNotIn("Go poop", self.getOutput(mock))

		# Make sure a week later, the reminder is back at 3pm
		self.setNow(dateMock, self.MON_3PM + datetime.timedelta(days=7))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processAllReminders()
			self.assertIn("Go poop", self.getOutput(mock))

	# Make sure we can say "done" to a weekly task and the task still shows up next time
	def test_done_entry_has_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Court on the 5th of aug tomorrow")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "done with court August 5")
			self.assertIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))

	# Make sure we can say "done" to a weekly task and the task still shows up next time
	def test_create_and_done_counts(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Go poop tomorrow")
		self.assertEqual(1, self.getTestUser().create_todo_count)

		cliMsg.msg(self.testPhoneNumber, "done")
		self.assertEqual(1, self.getTestUser().done_count)

	def test_question_and_reminders(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Why didn't I get my daily reminders yet?")
			self.assertEqual("", self.getOutput(mock))

		self.assertTrue(self.getTestUser().paused)

	def test_change_morning_summary_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Give me my morning summary at 7:30am")
			self.assertIn("7:30am", self.getOutput(mock))

		self.assertEquals(7, self.getTestUser().digest_hour)
		self.assertEquals(30, self.getTestUser().digest_minute)

	def test_default_entry_with_different_digest_time(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "buy sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "send my daily summary at 8am")

		self.setNow(dateMock, self.TUE_8AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn("Buy sox", self.getOutput(mock))

			# Make sure 9am doesn't show up (like it was a timed reminder)
			self.assertNotIn("9", self.getOutput(mock))

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertEqual("", self.getOutput(mock))

	def test_default_entry_then_snooze(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "buy sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertTrue(entry.use_digest_time)

		self.setNow(dateMock, self.TUE_9AM)
		async.processAllReminders()
		# Do a time in the future, so we shouldn't doing digest time
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "snooze 2 hours")

		entry = Entry.objects.get(label="#reminders")
		self.assertFalse(entry.use_digest_time)

		# now we should be using digest time since its a day without a time
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "snooze tomorrow")

		entry = Entry.objects.get(label="#reminders")
		self.assertTrue(entry.use_digest_time)

	def test_default_entry_then_followup(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "buy sox tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertTrue(entry.use_digest_time)

		# Do a time in the future, so we shouldn't doing digest time
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "in 60 minutes")

		entry = Entry.objects.get(label="#reminders")
		self.assertFalse(entry.use_digest_time)

	def test_done_slash_w(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)
		cliMsg.msg(self.testPhoneNumber, "remind me Call granny")
		cliMsg.msg(self.testPhoneNumber, "remind me Call regions401k")
		cliMsg.msg(self.testPhoneNumber, "remind me Chi bday")

		self.setNow(dateMock, self.MON_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			cliMsg.msg(self.testPhoneNumber, "Done w/Chi")
			self.assertIn("that off", self.getOutput(mock))

		entries = Entry.objects.filter(label="#reminders")
		self.assertFalse(entries[0].hidden)
		self.assertFalse(entries[1].hidden)
		self.assertTrue(entries[2].hidden)

	# Had a bug where "check" was being removed so squashes were over aggressive
	def test_squash_over_aggressive(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "Leave work tonight at 11:20")
		cliMsg.msg(self.testPhoneNumber, "Cash check tomorrow morning")

		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(2, len(entries))

	def test_digest_time_cleared(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind me to test")

		entry = Entry.objects.get(id=1)
		self.assertTrue(entry.use_digest_time, "Digest time not initially set")
		entry.remind_timestamp = self.TUE_10AM
		entry.save()
		self.assertFalse(entry.use_digest_time, "Digest time not cleared on manual remind_timestamp change")

	def test_delete_all(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind me to test foo bar")
		cliMsg.msg(self.testPhoneNumber, "Remind me to go poop tonight")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remove poop")
			self.assertNotIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))
			cliMsg.msg(self.testPhoneNumber, "tasks")
			self.assertNotIn("poop", self.getOutput(mock))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete all tasks")
			self.assertNotIn(self.renderTextConstant(":white_check_mark:"), self.getOutput(mock))
			self.assertNotIn("foo bar", self.getOutput(mock))
			self.assertNotIn("poop", self.getOutput(mock))

	def test_silent_stop(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Silent stop")
			self.assertEqual("", self.getOutput(mock))
			self.assertEqual(self.getTestUser().state, keeper_constants.STATE_STOPPED)

	def test_multisend_list(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Buy socks")
		cliMsg.msg(self.testPhoneNumber, "And shoes")
		cliMsg.msg(self.testPhoneNumber, "Also pants")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "todo")
			self.assertIn("socks", self.getOutput(mock))
			self.assertIn("Shoes", self.getOutput(mock))
			self.assertIn("Pants", self.getOutput(mock))
			self.assertNotIn("And", self.getOutput(mock))
			self.assertNotIn("Also", self.getOutput(mock))
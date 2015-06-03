from mock import patch

from smskeeper import cliMsg, keeper_constants
from smskeeper.models import Entry

import test_base


class SMSKeeperRemindTutorialCase(test_base.SMSKeeperBaseCase):

	def test_tutorial_remind_normal(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", self.getOutput(mock))
			self.assertEquals(self.getTestUser().name, "UnitTests")

		# Activation message asks for their zip
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "10012")
			self.assertIn("Let me show you how to set reminders", self.getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call mom tomorrow")
			self.assertIn("tomorrow around 9am", self.getOutput(mock))
			self.assertIn("I can also help you with other things", self.getOutput(mock))

	def test_tutorial_remind_no_time_given(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "10012")

		with patch('smskeeper.async.recordOutput') as mock:
			with patch('smskeeper.states.remind.datetime') as datetimeMock:
				# We set the time to be 10 am so we can check the default time later.
				# But need to set early otherwise default could be tomorrow
				datetimeMock.datetime.now.return_value = self.getUserNow().replace(hour=10)
				cliMsg.msg(self.testPhoneNumber, "Remind me to call mom")

				# Since there was no time given, should have picked a time in the near future
				self.assertIn("today around 6pm", self.getOutput(mock))

				# This is the key here, make sure we have the extra message
				self.assertIn("If that time doesn't work", self.getOutput(mock))

	def test_tutorial_remind_time_zones(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call mom")

			# Since there was no time given, should have picked a time in the near future
			self.assertIn("today", self.getOutput(mock))

			# This is the key here, make sure we have the extra message
			self.assertIn("If that time doesn't work", self.getOutput(mock))

	def test_tutorial_zip_code(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		user = self.getTestUser()
		self.assertEqual(user.timezone, "US/Pacific")

	def test_name_with_punctuation(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests.")

		user = self.getTestUser()
		self.assertEqual(user.name, "UnitTests")

	def test_name_with_phrase(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "My names kelly.")

		user = self.getTestUser()
		self.assertEqual(user.name, "kelly")

	def test_nicety(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		with patch('smskeeper.async.recordOutput') as mock:
			# Activation message asks for their name, but instead respond with nicety
			cliMsg.msg(self.testPhoneNumber, "Hey")
			self.assertIn("Hi there", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "Billy")
		user = self.getTestUser()
		self.assertEqual(user.name, "Billy")

	def test_name_looks_like_nicety(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		cliMsg.msg(self.testPhoneNumber, "Tymarieo")
		user = self.getTestUser()
		self.assertEqual(user.name, "Tymarieo")

	"""
	TODO(Derek): Get this to work
	def test_stop(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		with patch('smskeeper.async.recordOutput') as mock:
			# Activation message asks for their name, but instead respond with nicety
			cliMsg.msg(self.testPhoneNumber, "Hey")
			self.assertIn("Hi there", self.getOutput(mock))

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Stop")
			self.assertIn("I won't txt you anymore", self.getOutput(mock))
		user = self.getTestUser()
		self.assertEqual(user.state, keeper_constants.STATE_STOPPED)
	"""

	def test_long_sentence(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		with patch('smskeeper.async.recordOutput') as mock:
			# Activation message asks for their name, but instead respond with sentence
			cliMsg.msg(self.testPhoneNumber, "What are you?")
			self.assertIn("but first what's your name?", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "I'm Billy")
		user = self.getTestUser()
		self.assertEqual(user.name, "Billy")

	def test_tutorial_zip_code_again(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I'm in 94117")
			self.assertEquals("Got it.", self.getOutput(mock))

		# Make sure no reminders were created
		self.assertEquals(0, len(Entry.objects.filter(label="#reminders")))

		cliMsg.msg(self.testPhoneNumber, "Remind me to go poop later")
		# Make sure now messages are still though of as a reminder
		self.assertEquals(1, len(Entry.objects.filter(label="#reminders")))

from mock import patch

from smskeeper import cliMsg, keeper_constants
from smskeeper.models import Entry

import test_base


class SMSKeeperTodoTutorialCase(test_base.SMSKeeperBaseCase):

	def setupUser(self):
		super(SMSKeeperTodoTutorialCase, self).setupUser(True, False, keeper_constants.STATE_TUTORIAL_TODO, productId=1)

	def test_tutorial_remind_normal(self):
		self.setupUser()

		# Activation message asks for their name
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", self.getOutput(mock))
			self.assertEquals(self.getTestUser().name, "UnitTests")

		# Activation message asks for their zip
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "10012")
			self.assertIn("Let's add something you need to get done.", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call jesus tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertIn("What's something you need to get done", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Wish Dad happy birthday next week")
			self.assertIn("Mon", self.getOutput(mock))
			self.assertIn("daily morning digest", self.getOutput(mock))

	def test_tutorial_remind_nicety(self):
		self.setupUser()

		# Activation message asks for their name
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", self.getOutput(mock))
			self.assertEquals(self.getTestUser().name, "UnitTests")

		# Activation message asks for their zip
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "10012")
			self.assertIn("Let's add something you need to get done.", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hello")
			self.assertNotIn("I'll send you what you need to do at the best time", self.getOutput(mock))

	def test_tutorial_zip_code_again(self):
		self.setupUser()

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I'm in 94117")
			self.assertEquals("", self.getOutput(mock))

		# Make sure no reminders were created
		self.assertEquals(0, len(Entry.objects.filter(label="#reminders")))

		cliMsg.msg(self.testPhoneNumber, "Remind me to go poop later")
		# Make sure now messages are still though of as a reminder
		self.assertEquals(1, len(Entry.objects.filter(label="#reminders")))

	def test_tutorial_zip_code(self):
		self.setupUser()

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		user = self.getTestUser()
		self.assertEqual(user.timezone, "US/Pacific")

	def test_name_with_punctuation(self):
		self.setupUser()

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests.")

		user = self.getTestUser()
		self.assertEqual(user.name, "UnitTests")

	def test_name_with_phrase(self):
		self.setupUser()

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "My names kelly.")

		user = self.getTestUser()
		self.assertEqual(user.name, "kelly")

	def test_nicety(self):
		self.setupUser()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			# Activation message asks for their name, but instead respond with nicety
			cliMsg.msg(self.testPhoneNumber, "Hey")
			self.assertIn("Hi there", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "Billy")
		user = self.getTestUser()
		self.assertEqual(user.name, "Billy")

	def test_name_looks_like_nicety(self):
		self.setupUser()

		cliMsg.msg(self.testPhoneNumber, "Tymarieo")
		user = self.getTestUser()
		self.assertEqual(user.name, "Tymarieo")

	def test_stop(self):
		self.setupUser()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			# Activation message asks for their name, but instead respond with nicety
			cliMsg.msg(self.testPhoneNumber, "Hey")
			self.assertIn("Hi there", self.getOutput(mock))

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Stop")
			self.assertIn("I won't txt you anymore", self.getOutput(mock))
		user = self.getTestUser()
		self.assertEqual(user.state, keeper_constants.STATE_STOPPED)

	def test_long_sentence(self):
		self.setupUser()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			# Activation message asks for their name, but instead respond with sentence
			cliMsg.msg(self.testPhoneNumber, "What are you")
			self.assertIn("but first what's your name?", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "I'm Billy")
		user = self.getTestUser()
		self.assertEqual(user.name, "Billy")
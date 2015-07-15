import datetime
import pytz

from mock import patch

from smskeeper import cliMsg, keeper_constants
from smskeeper.models import Entry

import test_base


@patch('common.date_util.utcnow')
class SMSKeeperTodoTutorialCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, dateMock):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		super(SMSKeeperTodoTutorialCase, self).setupUser(True, False, keeper_constants.STATE_TUTORIAL_TODO, productId=1)

	def test_tutorial_remind_normal(self, dateMock):
		self.setupUser(dateMock)

		# Activation message asks for their name
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", self.getOutput(mock))
			self.assertEquals(self.getTestUser().name, "UnitTests")

		# Activation message asks for their zip
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "10012")
			self.assertIn("Let's add something you need to get done.", self.getOutput(mock))
			self.assertEqual(self.getTestUser().postal_code, "10012")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call jesus tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertIn("daily tasks", self.getOutput(mock))

	# Make sure that we ignore all messages without zip codes for 20 seconds during tutorial
	def test_tutorial_only_barfs_after_2_minutes(self, dateMock):
		self.setupUser(dateMock)

		now = datetime.datetime.now(pytz.utc)
		self.setNow(dateMock, now)

		# Activation message asks for their name
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", self.getOutput(mock))
			self.assertEquals(self.getTestUser().name, "UnitTests")

		# Immediatly after, should ignore
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "blah is this thing")
			self.assertEquals("", self.getOutput(mock))

		later = now + datetime.timedelta(minutes=5)
		self.setNow(dateMock, later)

		# Immediatly after, should ignore
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "blah is this thing2")
			self.assertIn("what's your zipcode?", self.getOutput(mock))

	def test_tutorial_remind_nicety(self, dateMock):
		self.setupUser(dateMock)

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

	def test_tutorial_zip_code_again(self, dateMock):
		self.setupUser(dateMock)

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

	def test_tutorial_zip_code(self, dateMock):
		self.setupUser(dateMock)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		user = self.getTestUser()
		self.assertEqual(user.timezone, "US/Pacific")

	def test_name_with_punctuation(self, dateMock):
		self.setupUser(dateMock)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests.")

		user = self.getTestUser()
		self.assertEqual(user.name, "UnitTests")

	def test_name_with_phrase(self, dateMock):
		self.setupUser(dateMock)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "My names kelly.")

		user = self.getTestUser()
		self.assertEqual(user.name, "kelly")

	def test_nicety(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			# Activation message asks for their name, but instead respond with nicety
			cliMsg.msg(self.testPhoneNumber, "Hey")
			self.assertIn("Hi there", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "Billy")
		user = self.getTestUser()
		self.assertEqual(user.name, "Billy")

	def test_name_looks_like_nicety(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "Tymarieo")
		user = self.getTestUser()
		self.assertEqual(user.name, "Tymarieo")

	def test_stop(self, dateMock):
		self.setupUser(dateMock)

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

	def test_long_sentence(self, dateMock):
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			# Activation message asks for their name, but instead respond with sentence
			cliMsg.msg(self.testPhoneNumber, "What are you")
			self.assertIn("but first what's your name?", self.getOutput(mock))

		cliMsg.msg(self.testPhoneNumber, "I'm Billy")
		user = self.getTestUser()
		self.assertEqual(user.name, "Billy")

	def test_tutorial_no_time(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "10012")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Need to call bobby")
			self.assertIn("reminded?", self.getOutput(mock))
			self.assertNotIn("It's that easy. ", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tomorrow")
			self.assertIn("tomorrow", self.getOutput(mock))
			self.assertNotIn("If that time doesn't work", self.getOutput(mock))
			self.assertIn("It's that easy. ", self.getOutput(mock))

	# Hit bug where a done command in the tutorial was bouncing out
	def test_tutorial_done_in_reminder(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "10012")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "help bobby get his shit done")
			self.assertIn("reminded?", self.getOutput(mock))
			self.assertNotIn("It's that easy. ", self.getOutput(mock))

	def test_tutorial_time_not_given_same_day(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10AM)

		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "10012")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Do homework when the cable guy leaves")
			self.assertIn("reminded?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "5:30 P.M")
			self.assertIn("today by 5:30pm", self.getOutput(mock))

	def test_tutorial_time_not_given_next_day(self, dateMock):
		self.setupUser(dateMock)

		self.setNow(dateMock, self.MON_10PM)

		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "10012")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Do homework when the cable guy leaves")
			self.assertIn("reminded?", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "5:30 P.M")
			self.assertIn("tomorrow by 5:30pm", self.getOutput(mock))


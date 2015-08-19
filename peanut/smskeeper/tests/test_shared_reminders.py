import datetime
import pytz
from mock import patch

from smskeeper.models import Entry
from smskeeper import cliMsg, tips
from smskeeper import async, keeper_constants

import test_base


@patch('common.date_util.utcnow')
class SMSKeeperSharedReminderCase(test_base.SMSKeeperBaseCase):
	def setupUser(self, dateMock):
		self.setNow(dateMock, self.MON_8AM)
		return super(SMSKeeperSharedReminderCase, self).setupUser(True, True)

	"""
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
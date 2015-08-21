import datetime
import pytz
from mock import patch

from smskeeper.models import Entry, User
from smskeeper import cliMsg, tips
from smskeeper import async, keeper_constants
from smskeeper.chunk import Chunk

import test_base


@patch('common.date_util.utcnow')
class SMSKeeperSharedReminderCase(test_base.SMSKeeperBaseCase):
	def setupUser(self, dateMock):
		self.setNow(dateMock, self.MON_8AM)
		return super(SMSKeeperSharedReminderCase, self).setupUser(True, True)

	def test_handle_extraction(self, dateMock):
		positiveSubjects = ["mom", "Bill", "Aseem", "dad", "my mom", "my boyfriend", "my wife"]
		negativeSubjects = ["to", "her", "him", "tomorrow", "Wednesday", "every", "of"]
		positiveStructures = [
			"Remind :SUBJECT: to foo bar baz tomorrow",
			"Remind :SUBJECT: about the dentist",
			"Remind :SUBJECT: this weekend to pack goggles",
			"Remind :SUBJECT: by tomorrow pack goggles",
			"Remind :SUBJECT: at 5pm pack goggles",
			"Remind :SUBJECT: in an hour pack goggles",
		]
		negativeStructures = [
			"Remind me to call :SUBJECT: this weekend",
			"Remind me to email :SUBJECT: to send his presentation to Susan",
			"Remind me in 10 mintues to remind :SUBJECT: to eat"
		]

		for structure in positiveStructures:
			for subject in positiveSubjects:
				chunk = Chunk(structure.replace(":SUBJECT:", subject))
				self.assertIn(subject.replace("my ", ""), chunk.handles(), "Handles not found in %s" % (chunk.originalText))

			for subject in negativeSubjects:
				chunk = Chunk(structure.replace(":SUBJECT:", subject))
				self.assertNotIn(subject, chunk.handles(), "Bad handles %s found in %s" % (chunk.handles(), chunk.originalText))

		for structure in negativeStructures:
			for subject in positiveSubjects:
				chunk = Chunk(structure.replace(":SUBJECT:", subject))
				self.assertEqual([], chunk.handles(), "Bad handles %s found in %s" % (chunk.handles(), chunk.originalText))

			for subject in negativeSubjects:
				chunk = Chunk(structure.replace(":SUBJECT:", subject))
				self.assertEqual([], chunk.handles(), "Bad handles %s found in %s" % (chunk.handles(), chunk.originalText))

	'''
	def test_shared_reminder_normal(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "Remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, "+16505555555")

		# Make sure other user was created successfully
		otherUser = User.objects.get(phone_number=phoneNumber)
		self.assertEqual(otherUser.state, keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER)

		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure entries were created correctly
		self.assertEquals(2, len(entry.users.all()))

	def test_shared_reminder_for_existing_user(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, "+16505555555")
		cliMsg.msg(self.testPhoneNumber, "remind mom to go poop Sunday at 10 am")

		entries = Entry.objects.filter(label="#reminders")

		# Make sure entries were created correctly
		self.assertEquals(2, len(entries))
		# Make sure entries were both shared
		self.assertEquals(2, len(entries[0].users.all()))
		self.assertEquals(2, len(entries[1].users.all()))


	def test_shared_reminder_nicety(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "hi")
			# Make sure
			self.assertIn("Hi there.", self.getOutput(mock))


	def test_shared_reminder_other_person_tell_me_more(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "tell me more")
			# See if it goes into tutorial
			self.assertIn(self.getOutput(mock), keeper_constants.HELP_MESSAGES)

	def test_shared_reminder_other_person_paused(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		cliMsg.msg(phoneNumber, "who is this?")
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
			self.assertIn("Bob", self.getOutput(mock))
			self.assertIn("pill", self.getOutput(mock))

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
			cliMsg.msg(phoneNumber, "remind me again in 1 hour")
			self.assertIn("later", self.getOutput(mock))
	'''
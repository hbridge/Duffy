import datetime
import pytz
from mock import patch

from smskeeper.models import Entry, User
from smskeeper import cliMsg, tips
from smskeeper import async, keeper_constants
from smskeeper.chunk import Chunk
import re

import test_base


@patch('common.date_util.utcnow')
class SMSKeeperSharedReminderCase(test_base.SMSKeeperBaseCase):
	recipientPhoneNumber = "+16505555555"

	def setupUser(self, dateMock):
		self.setNow(dateMock, self.MON_8AM)
		return super(SMSKeeperSharedReminderCase, self).setupUser(True, True)

	def createSharedReminder(self, createText="Remind mom to take her pill tomorrow morning"):
		cliMsg.msg(self.testPhoneNumber, createText)
		cliMsg.msg(self.testPhoneNumber, self.recipientPhoneNumber)

		entry = Entry.objects.filter(label="#reminders").last()
		return entry

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

	def test_shared_reminder_normal(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind mom to take her pill tomorrow morning")
			self.assertIn("mom's", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, phoneNumber)
			self.assertIn(self.user.name, self.getOutput(mock))
			# make sure we intro oursevles the first time
			self.assertIn("assistant", self.getOutput(mock))

		# Make sure other user was created successfully
		otherUser = User.objects.get(phone_number=phoneNumber)
		self.assertEqual(otherUser.state, keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER)

		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure entries were created correctly
		self.assertEquals(2, len(entry.users.all()))

	def test_shared_minitip(self, dateMock):
		self.setupUser(dateMock)
		self.assertTrue(tips.isUserEligibleForMiniTip(self.getTestUser(), tips.SHARED_REMINDER_MINI_TIP_ID))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			self.createSharedReminder()
			self.assertIn(tips.tipWithId(tips.SHARED_REMINDER_MINI_TIP_ID).render(self.getTestUser()), self.getOutput(mock))

	def test_shared_reminder_text(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "Remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		entry = Entry.objects.filter(label="#reminders").last()
		# Make sure entries were created correctly
		self.assertNotIn("mom", entry.text.lower())
		self.assertNotIn("to", entry.text.lower())

	def test_bad_capitalization(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Can You Remind Me Around 8 To Put Medicine, Pillow, Minion In Suitcase")
			self.assertNotIn("phone number", self.getOutput(mock))

	def test_other_action_for_object(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Call Dr at 11:30 in the morning")
			self.assertNotIn("phoneNumber", self.getOutput(mock))

	def test_shared_reminder_for_existing_user(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, "+16505555555")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind mom to go poop Sunday at 10 am")
			# make sure the creator gets a confirmation
			self.assertIn("mom", self.getOutput(mock))

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
			self.assertIn(
				self.renderTextConstant(keeper_constants.SHARED_REMINDER_RECIPIENT_UPSELL),
				self.getOutput(mock)
			)

		# make sure silent nicities work
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "cool")
			self.assertNotIn("None", self.getOutput(mock))

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
		self.setNow(dateMock, self.MON_9AM)  # have to set time to pause

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "who is this?")
			otherUser = User.objects.get(phone_number=phoneNumber)
			self.assertTrue(otherUser.paused, "Didn't pause user: " + self.getOutput(mock))

	def test_shared_reminder_digest(self, dateMock):
		user = self.setupUser(dateMock)
		self.setNow(dateMock, self.MON_8AM)
		entry = self.createSharedReminder("Remind mom to take her medicine at 11 am tomorrow")
		recipient = User.objects.get(phone_number=self.recipientPhoneNumber)

		# move clock to tuesday make sure there's no digest for unactivated recipient
		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest(startAtId=(recipient.id - 1))
			self.assertNotIn(entry.text, self.getOutput(mock))

		# make sure it is in the creators digest, and only once
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "todo")
			# make sure that the shared reminder is in the digest
			self.assertIn(entry.text, self.getOutput(mock))
			# but only once
			self.assertEqual(len(re.findall(entry.text, self.getOutput(mock))), 1)

		# activate the recipient, add another todo and make sure the item appears in the recipients digest
		recipient.setActivated(True, tutorialState=keeper_constants.STATE_NORMAL)
		recipient.completed_tutorial = True
		recipient.name = "Mom"
		recipient.signature_num_lines = 0
		recipient.save()

		entry = self.createSharedReminder("Remind mom to take her medicine at 11 am Wednesday")
		self.setNow(dateMock, self.WED_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest(startAtId=(recipient.id - 1))
			# make sure that the shared reminder is in the digest
			self.assertIn(entry.text, self.getOutput(mock))
			# but only once
			self.assertEqual(len(re.findall(entry.text, self.getOutput(mock))), 1)

			# make sure the name of the creator is listed with the todo
			self.assertIn(" (%s)" % self.getTestUser().name, self.getOutput(mock))


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
			self.assertIn("mom", self.getOutput(mock))

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

	def test_shared_reminder_onetime(self, dateMock):
		# all shared reminders should be one-time for now
		self.setupUser(dateMock)
		entry = self.createSharedReminder()
		self.assertEqual(entry.remind_recur, keeper_constants.RECUR_ONE_TIME)

	def test_shared_reminder_upsell(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, phoneNumber)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "hi")
			# Make sure upsell is shown
			self.assertIn(
				self.renderTextConstant(keeper_constants.SHARED_REMINDER_RECIPIENT_UPSELL),
				self.getOutput(mock)
			)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(phoneNumber, "hi")
			# Make sure upsell is not shown
			self.assertNotIn(
				self.renderTextConstant(keeper_constants.SHARED_REMINDER_RECIPIENT_UPSELL),
				self.getOutput(mock)
			)

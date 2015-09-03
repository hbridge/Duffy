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
		positiveSubjects = ["mom", "Bill", "Aseem", "dad", "my mom", "my boyfriend", "my wife", "steve"]
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
			"Remind me in 10 mintues to remind :SUBJECT: to eat",
			"Remind me I have and appointment :SUBJECT: September 17 at 1:00",
			"Remind me NOT to :SUBJECT: in an hour",
			"Remind September 1st to test :SUBJECT:"
		]

		for structure in positiveStructures:
			for subject in positiveSubjects:
				chunk = Chunk(structure.replace(":SUBJECT:", subject))
				self.assertIn(subject.replace("my ", "").lower(), chunk.sharedReminderHandles(), "Handles not found in %s" % (chunk.originalText))

			for subject in negativeSubjects:
				chunk = Chunk(structure.replace(":SUBJECT:", subject))
				self.assertNotIn(subject, chunk.sharedReminderHandles(), "Bad handles %s found in %s" % (chunk.sharedReminderHandles(), chunk.originalText))

		for structure in negativeStructures:
			for subject in positiveSubjects:
				chunk = Chunk(structure.replace(":SUBJECT:", subject))
				self.assertEqual(
					[],
					chunk.sharedReminderHandles(),
					"Bad handles %s found in %s" % (chunk.sharedReminderHandles(), chunk.originalText)
				)

			for subject in negativeSubjects:
				chunk = Chunk(structure.replace(":SUBJECT:", subject))
				self.assertEqual(
					[],
					chunk.sharedReminderHandles(),
					"Bad handles %s found in %s" % (chunk.sharedReminderHandles(), chunk.originalText)
				)

	def test_shared_reminder_recipient_nonuser(self, dateMock):
		phoneNumber = "+16505555555"
		self.setupUser(dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind mom to take her pill tomorrow morning")
			self.assertIn("remind you", self.getOutput(mock))  # make sure we tell them we'll remind them
			self.assertIn(self.renderTextConstant(keeper_constants.FOLLOWUP_SHARE_UNRESOLVED_TEXT), self.getOutput(mock))  # make sure we upsell them to remind mom

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, phoneNumber)
			self.assertIn("mom tomorrow", self.getOutput(mock))
			self.assertIn(self.user.name, self.getOutput(mock))
			# make sure we intro oursevles the first time
			self.assertIn("assistant", self.getOutput(mock))

		# Make sure other user was created successfully
		otherUser = User.objects.get(phone_number=phoneNumber)
		self.assertEqual(otherUser.state, keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER)

		# Make sure the entry has two users
		entry = Entry.objects.filter(label="#reminders").last()
		self.assertEquals(2, len(entry.users.all()))

	def test_shared_reminder_recipient_user(self, dateMock):
		self.setupUser(dateMock)
		recipient = self.setupAnotherUser(self.recipientPhoneNumber, True, True, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			self.createSharedReminder()
			self.assertNotIn(self.renderTextConstant(keeper_constants.SHARED_REMINDER_RECIPIENT_UPSELL), self.getOutput(mock))

		# make sure we don't change the recipient's state
		self.assertEqual(recipient.state, keeper_constants.STATE_NORMAL)

		# Make sure entry was created correctly
		entries = Entry.objects.filter(label="#reminders")
		self.assertEquals(2, len(entries[0].users.all()))

	def test_shared_reminder_2nd_time(self, dateMock):
		self.setupUser(dateMock)
		self.createSharedReminder()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind mom to call me in a week")
			self.assertNotIn(keeper_constants.FOLLOWUP_SHARE_UNRESOLVED_TEXT, self.getOutput(mock))
			self.assertIn(self.renderTextConstant(keeper_constants.FOLLOWUP_SHARE_RESOLVED_TEXT), self.getOutput(mock))
			cliMsg.msg(self.testPhoneNumber, "Text mom")

		# Make sure both entries were shared
		entries = Entry.objects.filter(label="#reminders")
		for entry in entries:
			self.assertEquals(2, len(entry.users.all()))

	def test_shared_reminder_text(self, dateMock):
		self.setupUser(dateMock)

		entry = self.createSharedReminder()
		# Make sure entries were created correctly
		self.assertNotIn("mom", entry.text.lower())
		self.assertNotIn("to", entry.text.lower())

	def test_bad_capitalization(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Can You Remind Me Around 8 To Put Medicine, Pillow, Minion In Suitcase")
		self.assertFalse(self.getTestUser().wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SHARE_PROMPT))

	def test_other_action_for_object(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Call Dr at 11:30 in the morning")
		self.assertFalse(self.getTestUser().wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SHARE_PROMPT))

	def test_shared_reminder_nicety(self, dateMock):
		self.setupUser(dateMock)
		self.createSharedReminder()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.recipientPhoneNumber, "hi")
			# Make sure
			self.assertIn(
				self.renderTextConstant(keeper_constants.SHARED_REMINDER_RECIPIENT_UPSELL),
				self.getOutput(mock)
			)

		# make sure silent nicities work
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.recipientPhoneNumber, "cool")
			self.assertNotIn("None", self.getOutput(mock))

	def test_shared_reminder_other_person_tell_me_more(self, dateMock):
		self.setupUser(dateMock)
		self.createSharedReminder()

		cliMsg.msg(self.testPhoneNumber, "remind mom to take her pill tomorrow morning")
		cliMsg.msg(self.testPhoneNumber, self.recipientPhoneNumber)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.recipientPhoneNumber, "tell me more")
			# See if it goes into tutorial
			self.assertIn("what's your name?", self.getOutput(mock))

	def test_shared_reminder_other_person_paused(self, dateMock):
		self.setupUser(dateMock)
		self.setNow(dateMock, self.MON_9AM)  # have to set time to pause

		self.createSharedReminder()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.recipientPhoneNumber, "who is this?")
			otherUser = User.objects.get(phone_number=self.recipientPhoneNumber)
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
		user = self.setupUser(dateMock)
		user.name = "Bob"
		user.save()

		entry = self.createSharedReminder("remind mom to take her pill in one minute")

		# Now make it process the record, like the reminder fired
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processReminder(entry)
			self.assertIn("Bob", self.getOutput(mock))
			self.assertIn("pill", self.getOutput(mock))
			self.assertIn("mom", self.getOutput(mock))

	def test_shared_reminder_snooze(self, dateMock):
		self.setupUser(dateMock)
		entry = self.createSharedReminder("remind mom to take her pill in one minute")

		# Make the user look like they've been using the product
		otherUser = User.objects.get(phone_number=self.recipientPhoneNumber)
		otherUser.completed_tutorial = True
		otherUser.setState(keeper_constants.STATE_NORMAL)
		otherUser.save()

		# Now make it process the record, like the reminder fired
		async.processReminder(entry)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.recipientPhoneNumber, "remind me again in 1 hour")
			self.assertIn("later", self.getOutput(mock))

	def test_shared_reminder_onetime(self, dateMock):
		# all shared reminders should be one-time for now
		self.setupUser(dateMock)
		entry = self.createSharedReminder()
		self.assertEqual(entry.remind_recur, keeper_constants.RECUR_ONE_TIME)

	def test_shared_reminder_upsell(self, dateMock):
		self.setupUser(dateMock)
		self.createSharedReminder()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.recipientPhoneNumber, "hi")
			# Make sure upsell is shown
			self.assertIn(
				self.renderTextConstant(keeper_constants.SHARED_REMINDER_RECIPIENT_UPSELL),
				self.getOutput(mock)
			)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.recipientPhoneNumber, "hi")
			# Make sure upsell is not shown a second time
			self.assertNotIn(
				self.renderTextConstant(keeper_constants.SHARED_REMINDER_RECIPIENT_UPSELL),
				self.getOutput(mock)
			)

	def test_short_shared_reminder(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind Steve to test")
		self.assertTrue(self.getTestUser().wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SHARE_PROMPT))

	def test_overagressive_share(self, dateMock):
		self.setupUser(dateMock)
		sharedEntry = self.createSharedReminder()
		cliMsg.msg(self.testPhoneNumber, "Remind mom to test")
		cliMsg.msg(self.testPhoneNumber, "Remind me to jump out a window this evening")
		cliMsg.msg(self.testPhoneNumber, "Remind me to eat grass")

		entries = Entry.objects.filter(label="#reminders")
		for entry in entries:
			if entry == sharedEntry:
				continue

			self.assertEqual(entry.users.count(), 1, "Entry erroneously shared: %s" % entry)

	def test_handle_cap_difference(self, dateMock):
		self.setupUser(dateMock)
		self.createSharedReminder()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind Mom to test")
			self.assertNotIn(
				self.renderTextConstant(keeper_constants.FOLLOWUP_SHARE_UNRESOLVED_TEXT),
				self.getOutput(mock)
			)
			self.assertIn(
				self.renderTextConstant(keeper_constants.FOLLOWUP_SHARE_RESOLVED_TEXT),
				self.getOutput(mock)
			)

	def test_multiple_handles_pause(self, dateMock):
		self.setupUser(dateMock)
		self.createSharedReminder("Remind Mon Petit Garcon about Medieval Times Sunday at 11am")
		self.assertTrue(self.getTestUser().paused)

	def test_handle_display(self, dateMock):
		self.setupUser(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			self.createSharedReminder("Remind mom to test tomorrow")
			self.assertIn("your mom", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			self.recipientPhoneNumber = "+16505552222"
			self.createSharedReminder("Remind susan to test tomorrow")
			self.assertIn("Susan", self.getOutput(mock))

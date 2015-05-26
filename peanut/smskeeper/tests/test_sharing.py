import datetime
import pytz
from mock import patch

from smskeeper.models import User, Entry, Contact
from smskeeper import msg_util, cliMsg, keeper_constants

import test_base


class SMSKeeperSharingCase(test_base.SMSKeeperBaseCase):
	testPhoneNumbers = ["+16505555550", "+16505555551", "+16505555552"]
	users = []
	handle = "@test"
	nonUserNumber = "6505551111"

	def normalizeNumber(self, number):
		return "+1" + number

	def createHandle(self, user_phone, handle, number):
		cliMsg.msg(user_phone, "%s %s" % (handle, number))

	def setUp(self):
		for user in User.objects.all():
			user.delete()
		self.users = []

		for phoneNumber in self.testPhoneNumbers:
			user, created = User.objects.get_or_create(phone_number=phoneNumber)
			user.completed_tutorial = True
			user.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
			user.state = keeper_constants.STATE_NORMAL
			user.save()
			self.users.append(user)

	def testExtractPhoneNumbers(self):
		numbers, remaining_str = msg_util.extractPhoneNumbers("9172827255")
		self.assertEqual(numbers, ["+19172827255"])
		self.assertEqual(remaining_str, "")
		numbers, remaining_str = msg_util.extractPhoneNumbers("9172827255 @henry")
		self.assertEqual(numbers, ["+19172827255"])
		self.assertEqual(remaining_str.strip(), "@henry")
		numbers, remaining_str = msg_util.extractPhoneNumbers("(917) 282-7255 @henry")
		self.assertEqual(numbers, ["+19172827255"])
		self.assertEqual(remaining_str.strip(), "@henry")

	def testCreateContact(self):
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "@test +16505555551")
			self.assertIn(self.testPhoneNumbers[1], self.getOutput(mock))

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.users[0], handle=self.handle)
		self.assertEqual(contact.target.phone_number, self.testPhoneNumbers[1])

		# try more complicated formatting
		cliMsg.msg(self.testPhoneNumbers[0], "@test2 (650) 555-5551")

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.users[0], handle="@test2")
		self.assertEqual(contact.target.phone_number, self.testPhoneNumbers[1])

	def testCreateNonUserContact(self):
		# make sure the output contains the normalized number
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.nonUserNumber))
			self.assertIn(self.normalizeNumber(self.nonUserNumber), self.getOutput(mock))

		# make sure there's a user for the new contact
		targetUser = User.objects.get(phone_number=self.normalizeNumber(self.nonUserNumber))
		self.assertNotEqual(targetUser, None)

	def testReassignContact(self):
		# create a contact
		cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[1]))

		# change it
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[2]))
			self.assertIn(self.testPhoneNumbers[2], self.getOutput(mock))

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.users[0], handle=self.handle)
		self.assertEqual(contact.target.phone_number, self.testPhoneNumbers[2])

	def testShareWithExsitingUser(self):
		self.createHandle(self.testPhoneNumbers[0], "@test", self.testPhoneNumbers[1])
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "item #list @test")
			self.assertIn("@test", self.getOutput(mock))

		# ensure that the phone number for user 0 is listed in #list for user 1
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[1], "#list")
			self.assertIn(self.testPhoneNumbers[0], self.getOutput(mock))

		# ensure that if user 1 creates a handle for user 0 that's used instead
		self.createHandle(self.testPhoneNumbers[1], "@user0", self.testPhoneNumbers[0])
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[1], "#list")
			self.assertIn("@user0", self.getOutput(mock))

	def testShareWithNewUser(self):
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "item #list @test")
			self.assertIn("@test", self.getOutput(mock))
			cliMsg.msg(self.testPhoneNumbers[0], "6505551111")

			# Make sure that the intro message was sent out to the new user
			self.assertIn("Hi there.", self.getOutput(mock))
		with patch('smskeeper.async.recordOutput') as mock:
			# make sure that the entry was actually shared with @test
			cliMsg.msg(self.testPhoneNumbers[0], "#list")
			self.assertIn("@test", self.getOutput(mock))

		# make sure the item is in @test's lists
		# do an actual entry fetch because the text responses for the user will be unactivated stuff etc
		newUser = User.objects.get(phone_number=self.normalizeNumber("6505551111"))
		entries = Entry.fetchEntries(newUser, "#list")
		self.assertEqual(len(entries), 1)

	def testFetchContact(self):
		# make sure getting an undefined handle doesn't crash
		cliMsg.msg(self.testPhoneNumbers[0], "@test")
		cliMsg.msg(self.testPhoneNumbers[0], "@test +16505555551")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "@Test")
			self.assertIn("6505555551", self.getOutput(mock))

	# TODO(Henry) add test cases for having multiple contacts for the same target user

	'''
	Ensure that shared items are deleted from all users lists
	'''
	def testShareDelete(self):
		self.createHandle(self.testPhoneNumbers[0], "@test", self.testPhoneNumbers[1])
		cliMsg.msg(self.testPhoneNumbers[0], "poop #list @test")
		cliMsg.msg(self.testPhoneNumbers[0], "delete 1 #list")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[1], "#list")
			self.assertNotIn("poop", self.getOutput(mock))


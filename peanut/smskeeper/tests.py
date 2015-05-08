import datetime
import pytz
import sys
from mock import patch
from cStringIO import StringIO
from contextlib import contextmanager

from testfixtures import Replacer
from testfixtures import test_datetime

from django.test import TestCase

from peanut.settings import constants
from smskeeper import views, processing_util, keeper_constants
from smskeeper.models import User, Entry, Contact, Message
from smskeeper import msg_util

from smskeeper import cliMsg

import string

def getOutput(mock):
	output = ""
	for call in mock.call_args_list:
		arg, kargs = call
		output += str(arg[0])

	return output

class SMSKeeperCase(TestCase):
	testPhoneNumber = "+16505555550"
	user = None

	def setUp(self):
		try:
			user = User.objects.get(phone_number=self.testPhoneNumber)
			user.delete()
		except User.DoesNotExist:
			pass

	# TODO(Derek): Eventually activated and tutorialComplete should go away
	def setupUser(self, activated, tutorialComplete, state=keeper_constants.STATE_NORMAL):
		self.user, created = User.objects.get_or_create(phone_number=self.testPhoneNumber)
		self.user.completed_tutorial = tutorialComplete
		if (activated):
			self.user.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		self.user.state = state
		self.user.save()

	def test_first_connect(self):
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi")
			self.assertIn("magic phrase", getOutput(mock))

	def test_unactivated_connect(self):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		cliMsg.msg(self.testPhoneNumber, "hi")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi")
			self.assertIn("Nope.", getOutput(mock))

	def test_magicphrase(self):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "trapper keeper")
			self.assertIn("That's the magic phrase", getOutput(mock))

	def test_tutorial(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL)

		# Activation message asks for their name
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", getOutput(mock))
			self.assertIn("Let me show you the basics", getOutput(mock))
			self.assertEquals(User.objects.get(phone_number=self.testPhoneNumber).name, "UnitTests")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new5 #test")
			self.assertIn("Now send me another item for the same list", getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new2 #test")
			self.assertIn("You can send items to this", getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("That's all you need to know for now", getOutput(mock))

	def test_get_label_doesnt_exist(self):
		self.setupUser(True, True)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("Sorry, I don't", getOutput(mock))

	def test_get_label(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("new", getOutput(mock))

	def test_pick_label(self):
		self.setupUser(True, True)
		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "pick #test")
			self.assertTrue("new", getOutput(mock))

	def test_print_hashtags(self):
		self.setupUser(True, True)
		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#hashtag")
			self.assertIn("(1)", getOutput(mock))

	def test_add_unassigned(self):
		self.setupUser(True, True)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new")
			# ensure we tell the user we put it in unassigned
			self.assertIn(keeper_constants.UNASSIGNED_LABEL, getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, keeper_constants.UNASSIGNED_LABEL)
			# ensure the user can get things from #unassigned
			self.assertIn("new", getOutput(mock))

	def test_no_add_dumb_stuff(self):
		self.setupUser(True, True)
		dumb_phrases = ["hi", "thanks", "no", "yes"]

		for phrase in dumb_phrases:
			with patch('smskeeper.sms_util.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, phrase)
				self.assertNotIn(keeper_constants.UNASSIGNED_LABEL, getOutput(mock))

	def test_absolute_delete(self):
		self.setupUser(True, True)
		# ensure deleting from an empty list doesn't crash
		cliMsg.msg(self.testPhoneNumber, "delete 1 #test")
		cliMsg.msg(self.testPhoneNumber, "old fashioned #cocktail")

		# First make sure that the entry is there
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertIn("old fashioned", getOutput(mock))

				# Next make sure we delete and the list is clear
		cliMsg.msg(self.testPhoneNumber, "delete 1 #cocktail")   # test absolute delete
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertIn("Sorry, I don't", getOutput(mock))

	def test_contextual_delete(self):
		self.setupUser(True, True)
		for i in range(1, 2):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we don't delete when ambiguous
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertIn("Sorry, I'm not sure", getOutput(mock))

				# ensure deletes right item
		cliMsg.msg(self.testPhoneNumber, "#bar")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 2")
			self.assertNotIn("2. foo2", getOutput(mock))

		# ensure can chain deletes
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("1. foo1", getOutput(mock))

		# ensure deleting from empty doesn't crash
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("I deleted", getOutput(mock))

	def test_multi_delete(self):
		self.setupUser(True, True)
		for i in range(1, 5):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we can delete with or without spaces
		cliMsg.msg(self.testPhoneNumber, "delete 3, 5,2 #bar")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#bar")

			self.assertNotIn("foo2", getOutput(mock))
			self.assertNotIn("foo3", getOutput(mock))
			self.assertNotIn("foo5", getOutput(mock))

	def test_reminders_basic(self):
		self.setupUser(True, True)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop tmr")
			self.assertIn("a day from now", getOutput(mock))

		self.assertIn("#reminders", Entry.fetchAllLabels(self.user))

	# This test is here to make sure the ordering of fetch vs reminders is correct
	def test_reminders_fetch(self):
		self.setupUser(True, True)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#reminders")
			self.assertIn("#reminders", getOutput(mock))

	def test_reminders_followup_change(self):
		self.setupUser(True, True)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop")
			self.assertIn("If that time doesn't work", getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tomorrow")
			self.assertIn("a day from now", getOutput(mock))

	def test_reminders_two_in_row(self):
		self.setupUser(True, True)

		#	cliMsg.msg(self.testPhoneNumber, "#remind poop")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop")
			self.assertIn("If that time doesn't work", getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind pee tomorrow")
			self.assertIn("pee", getOutput(mock))

	def test_reminders_defaults(self):
		self.setupUser(True, True)

		# Emulate the user sending in a reminder without a time for 9am, 3 pm and 10 pm
		with Replacer() as r:
			with patch('humanize.time._now') as mocked:
				tz = pytz.timezone('US/Eastern')
				# Try with 9 am EST
				testDt = test_datetime(2020, 01, 01, 9, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)

				# humanize.time._now should always return utcnow because that's what the
				# server's time is set in
				mocked.return_value = testDt.utcnow()
				with patch('smskeeper.sms_util.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 6 pm, so 9 hours
					self.assertIn("9 hours", getOutput(mock))

				# Try with 3 pm EST
				testDt = test_datetime(2020, 01, 01, 15, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = testDt.utcnow()
				with patch('smskeeper.sms_util.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 9 pm, so 6 hours
					self.assertIn("6 hours", getOutput(mock))

				# Try with 10 pm EST
				testDt = test_datetime(2020, 01, 01, 22, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = testDt.utcnow()
				with patch('smskeeper.sms_util.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 9 am next day, so in 11 hours
					self.assertIn("11 hours", getOutput(mock))

			r.replace('smskeeper.states.remind.datetime.datetime', datetime.datetime)


	"""
		Set a user first the Eastern and make sure it comes back as a utc time for 3 pm Eastern
		Then set the user's timezone to be Pacific and make sure natty returns a time for 3pm Pactific in UTC
	"""
	def test_natty_timezone(self):
		self.setupUser(True, True)
		self.user.timezone = "US/Eastern"  # This is the default
		self.user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop 3pm tomorrow")
			self.assertIn("poop", getOutput(mock))

		entry = Entry.fetchEntries(user=self.user, label="#reminders")[0]

		self.assertEqual(entry.remind_timestamp.hour, 19)  # 3 pm Eastern in UTC

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "clear #reminders")
			self.assertIn("cleared", getOutput(mock))

		self.user.timezone = "US/Pacific"  # This is the default
		self.user.save()
		cliMsg.msg(self.testPhoneNumber, "#remind poop 3pm tomorrow")

		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]

		self.assertEqual(entry.remind_timestamp.hour, 22)  # 3 pm Pactific in UTC


	def test_unicode_natty(self):
		self.setupUser(True, True)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, u'#remind poop\u2019s tmr')
			self.assertIn(u'poop\u2019s', getOutput(mock).decode('utf-8'))
		self.assertIn("#reminders", Entry.fetchAllLabels(self.user))

	def test_exception_error_message(self):
		self.setupUser(True, True)
		with self.assertRaises(NameError):
			cliMsg.msg(self.testPhoneNumber, 'yippee ki yay motherfucker')

		# we have to dig into messages as ouput would never get returned from the mock
		messages = Message.objects.filter(user=self.user, incoming=False).all()
		self.assertIn(removeNonAscii(keeper_constants.GENERIC_ERROR_MESSAGE), messages[0].msg_json)


def removeNonAscii(mystr):
	return filter(lambda x: x in string.printable, mystr)

class SMSKeeperSharingCase(TestCase):
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
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "@test +16505555551")
			self.assertIn(self.testPhoneNumbers[1], getOutput(mock))

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
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.nonUserNumber))
			self.assertIn(self.normalizeNumber(self.nonUserNumber), getOutput(mock))

		# make sure there's a user for the new contact
		targetUser = User.objects.get(phone_number=self.normalizeNumber(self.nonUserNumber))
		self.assertNotEqual(targetUser, None)

	def testReassignContact(self):
		# create a contact
		cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[1]))

		# change it
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[2]))
			self.assertIn(self.testPhoneNumbers[2], getOutput(mock))

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.users[0], handle=self.handle)
		self.assertEqual(contact.target.phone_number, self.testPhoneNumbers[2])

	def testShareWithExsitingUser(self):
		self.createHandle(self.testPhoneNumbers[0], "@test", self.testPhoneNumbers[1])
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "item #list @test")
			self.assertIn("@test", getOutput(mock))

		# ensure that the phone number for user 0 is listed in #list for user 1
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[1], "#list")
			self.assertIn(self.testPhoneNumbers[0], getOutput(mock))

		# ensure that if user 1 creates a handle for user 0 that's used instead
		self.createHandle(self.testPhoneNumbers[1], "@user0", self.testPhoneNumbers[0])
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[1], "#list")
			self.assertIn("@user0", getOutput(mock))

	def testShareWithNewUser(self):
		self.createHandle(self.testPhoneNumbers[0], "@test", "6505551111")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "item #list @test")
			self.assertIn("@test", getOutput(mock))

		# make sure the item is in @test's lists
		# do an actual entry fetch because the text responses for the user will be unactivated stuff etc
		newUser = User.objects.get(phone_number=self.normalizeNumber("6505551111"))
		entries = Entry.fetchEntries(newUser, "#list")
		self.assertEqual(len(entries), 1)

	'''
	Ensure that shared items are deleted from all users lists
	'''
	def testShareDelete(self):
		self.createHandle(self.testPhoneNumbers[0], "@test", self.testPhoneNumbers[1])
		cliMsg.msg(self.testPhoneNumbers[0], "poop #list @test")
		cliMsg.msg(self.testPhoneNumbers[0], "delete 1 #list")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[1], "#list")
			self.assertNotIn("poop", getOutput(mock))

from smskeeper import async
from smskeeper import tips


class SMSKeeperAsyncCase(TestCase):
	testPhoneNumber = "+16505555550"
	user = None

	def setUp(self):
		try:
			user = User.objects.get(phone_number=self.testPhoneNumber)
			user.delete()
		except User.DoesNotExist:
			pass

	def setupUser(self, activated, tutorialComplete):
		self.user, created = User.objects.get_or_create(phone_number=self.testPhoneNumber)
		self.user.completed_tutorial = tutorialComplete
		if (activated):
			self.user.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		self.user.name = "Bob"
		self.user.save()

	def testSendTips(self):
		self.setupUser(True, True)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertIn(tips.renderTip(tips.SMSKEEPER_TIPS[0], self.user.name), getOutput(mock))

		# set datetime to return a full day ahead after each call
		with Replacer() as r:
			r.replace('smskeeper.async.datetime.datetime', test_datetime(2020, 01, 01))
			# check that tip 2 got sent out
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.renderTip(tips.SMSKEEPER_TIPS[1], self.user.name), getOutput(mock))
			r.replace('smskeeper.async.datetime.datetime', datetime.datetime)

	def testTipThrottling(self):
		self.setupUser(True, True)
		async.sendTips(constants.SMSKEEPER_TEST_NUM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.renderTip(tips.SMSKEEPER_TIPS[1], self.user.name), getOutput(mock))

	def testTipsSkipIneligibleUsers(self):
		self.setupUser(True, False)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.renderTip(tips.SMSKEEPER_TIPS[0], self.user.name), getOutput(mock))


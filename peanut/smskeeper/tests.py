import datetime
import pytz
import sys
from cStringIO import StringIO
from contextlib import contextmanager

from testfixtures import Replacer
from testfixtures import test_datetime

from django.test import TestCase

from peanut.settings import constants
from smskeeper import views, processing_util, keeper_constants
from smskeeper.models import User, Entry, Contact


@contextmanager
def capture(command, *args, **kwargs):
	out, sys.stdout = sys.stdout, StringIO()
	command(*args, **kwargs)
	sys.stdout.seek(0)
	yield sys.stdout.read()
	sys.stdout = out


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
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertIn("magic phrase", output)

	def test_unactivated_connect(self):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		views.cliMsg(self.testPhoneNumber, "hi")
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertIn("Nope.", output)

	def test_magicphrase(self):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		with capture(views.cliMsg, self.testPhoneNumber, "trapper keeper") as output:
			self.assertIn("That's the magic phrase", output)

	def test_tutorial(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL)

		# Activation message asks for their name
		with capture(views.cliMsg, self.testPhoneNumber, "UnitTests") as output:
			self.assertIn("nice to meet you UnitTests!", output)
			self.assertIn("Let me show you the basics", output)
			self.assertEquals(User.objects.get(phone_number=self.testPhoneNumber).name, "UnitTests")

		with capture(views.cliMsg, self.testPhoneNumber, "new5 #test") as output:
			self.assertIn("Now send me another item for the same list", output)

		with capture(views.cliMsg, self.testPhoneNumber, "new2 #test") as output:
			self.assertIn("You can send items to this", output)

		with capture(views.cliMsg, self.testPhoneNumber, "#test") as output:
			self.assertIn("That's all you need to know for now", output)

	def test_get_label_doesnt_exist(self):
		self.setupUser(True, True)
		with capture(views.cliMsg, self.testPhoneNumber, "#test") as output:
			self.assertIn("Sorry, I don't", output)

	def test_get_label(self):
		self.setupUser(True, True)

		views.cliMsg(self.testPhoneNumber, "new #test")
		with capture(views.cliMsg, self.testPhoneNumber, "#test") as output:
			self.assertTrue("new" in output, output)

	def test_pick_label(self):
		self.setupUser(True, True)
		views.cliMsg(self.testPhoneNumber, "new #test")
		with capture(views.cliMsg, self.testPhoneNumber, "pick #test") as output:
			self.assertTrue("new" in output, output)

	def test_print_hashtags(self):
		self.setupUser(True, True)
		views.cliMsg(self.testPhoneNumber, "new #test")
		with capture(views.cliMsg, self.testPhoneNumber, "#hashtag") as output:
			self.assertTrue("(1)" in output, output)

	def test_add_unassigned(self):
		self.setupUser(True, True)
		with capture(views.cliMsg, self.testPhoneNumber, "new") as output:
			# ensure we tell the user we put it in unassigned
			self.assertIn(keeper_constants.UNASSIGNED_LABEL, output)
		with capture(views.cliMsg, self.testPhoneNumber, keeper_constants.UNASSIGNED_LABEL) as output:
			# ensure the user can get things from #unassigned
			self.assertIn("new", output)

	def test_absolute_delete(self):
		self.setupUser(True, True)
		# ensure deleting from an empty list doesn't crash
		views.cliMsg(self.testPhoneNumber, "delete 1 #test")
		views.cliMsg(self.testPhoneNumber, "old fashioned #cocktail")

		# First make sure that the entry is there
		with capture(views.cliMsg, self.testPhoneNumber, "#cocktail") as output:
			self.assertIn("old fashioned", output)

		# Next make sure we delete and the list is clear
		views.cliMsg(self.testPhoneNumber, "delete 1 #cocktail")   # test absolute delete
		with capture(views.cliMsg, self.testPhoneNumber, "#cocktail") as output:
			self.assertIn("Sorry, I don't", output)

	def test_contextual_delete(self):
		self.setupUser(True, True)
		for i in range(1, 2):
			views.cliMsg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we don't delete when ambiguous
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertIn("Sorry, I'm not sure", output)

		# ensure deletes right item
		views.cliMsg(self.testPhoneNumber, "#bar")
		with capture(views.cliMsg, self.testPhoneNumber, "delete 2") as output:
			self.assertNotIn("2. foo2", output)

		# ensure can chain deletes
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertNotIn("1. foo1", output)

		# ensure deleting from empty doesn't crash
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertNotIn("I deleted", output)

	def test_multi_delete(self):
		self.setupUser(True, True)
		for i in range(1, 5):
			views.cliMsg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we can delete with or without spaces
		with capture(views.cliMsg, self.testPhoneNumber, "delete 3, 5,2 #bar"):
			pass

		with capture(views.cliMsg, self.testPhoneNumber, "#bar") as output:
			self.assertNotIn("foo2", output)
			self.assertNotIn("foo3", output)
			self.assertNotIn("foo5", output)

	def test_reminders_basic(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, "#remind poop tmr") as output:
			self.assertIn("a day from now", output)

	def test_reminders_remind_works(self):
		self.setupUser(True, True)

		views.cliMsg(self.testPhoneNumber, "#remind poop tmr")
		self.assertIn("#reminders", Entry.fetchAllLabels(self.user))

	def test_reminders_fetch(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, "#reminders") as output:
			self.assertIn("#reminders", output)

	def test_reminders_followup(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, "#remind poop") as output:
			self.assertIn("what time?", output)

		with capture(views.cliMsg, self.testPhoneNumber, "tomorrow") as output:
			self.assertIn("a day from now", output)

	def test_reminders_double_followup(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, "#remind poop") as output:
			self.assertIn("what time?", output)

		with capture(views.cliMsg, self.testPhoneNumber, "I'm not sure") as output:
			self.assertIn("Sorry", output)

		with capture(views.cliMsg, self.testPhoneNumber, "tomorrow") as output:
			self.assertIn("a day from now", output)

	"""
		Set a user first the Eastern and make sure it comes back as a utc time for 3 pm Eastern
		Then set the user's timezone to be Pacific and make sure natty returns a time for 3pm Pactific in UTC
	"""
	def test_natty_timezone(self):
		self.setupUser(True, True)
		self.user.timezone = "US/Eastern"  # This is the default
		self.user.save()

		with capture(views.cliMsg, self.testPhoneNumber, "#remind poop 3pm tomorrow") as output:
			self.assertIn("poop", output)

		entry = Entry.fetchEntries(user=self.user, label="#reminders")[0]

		self.assertEqual(entry.remind_timestamp.hour, 19)  # 3 pm Eastern in UTC

		with capture(views.cliMsg, self.testPhoneNumber, "clear #reminders") as output:
			self.assertIn("cleared", output)

		self.user.timezone = "US/Pacific"  # This is the default
		self.user.save()
		views.cliMsg(self.testPhoneNumber, "#remind poop 3pm tomorrow")

		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]

		self.assertEqual(entry.remind_timestamp.hour, 22)  # 3 pm Pactific in UTC

	def test_state_machine(self):
		commands = processing_util.getPossibleCommands("#test this is a test")
		print "HERE: %s" % commands

	def test_unicode_natty(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, u'#remind poop\u2019s tmr') as output:
			self.assertIn(u'poop\u2019s', output.decode('utf-8'))
		self.assertIn("#reminders", Entry.fetchAllLabels(self.user))


class SMSKeeperSharingCase(TestCase):
	testPhoneNumbers = ["+16505555550", "+16505555551", "+16505555552"]
	users = []
	handle = "@test"
	nonUserNumber = "6505551111"

	def normalizeNumber(self, number):
		return "+1" + number

	def createHandle(self, user_phone, handle, number):
		with capture(views.cliMsg, user_phone, "%s %s" % (handle, number)):
			pass

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

	def testCreateContact(self):
		with capture(views.cliMsg, self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[1])) as output:
			self.assertTrue(self.testPhoneNumbers[1] in output)

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.users[0], handle=self.handle)
		self.assertEqual(contact.target.phone_number, self.testPhoneNumbers[1])

	def testCreateNonUserContact(self):
		# make sure the output contains the normalized number
		with capture(views.cliMsg, self.testPhoneNumbers[0], "%s %s" % (self.handle, self.nonUserNumber)) as output:
			self.assertTrue(self.normalizeNumber(self.nonUserNumber) in output)

		# make sure there's a user for the new contact
		targetUser = User.objects.get(phone_number=self.normalizeNumber(self.nonUserNumber))
		self.assertNotEqual(targetUser, None)

	def testReassignContact(self):
		# create a contact
		with capture(views.cliMsg, self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[1])) as output:
			pass

		# change it
		with capture(views.cliMsg, self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[2])) as output:
			self.assertIn(self.testPhoneNumbers[2], output)

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.users[0], handle=self.handle)
		self.assertEqual(contact.target.phone_number, self.testPhoneNumbers[2])

	def testShareWithExsitingUser(self):
		self.createHandle(self.testPhoneNumbers[0], "@test", self.testPhoneNumbers[1])
		with capture(views.cliMsg, self.testPhoneNumbers[0], "item #list @test") as output:
			self.assertIn("@test", output)

		# ensure that the phone number for user 0 is listed in #list for user 1
		with capture(views.cliMsg, self.testPhoneNumbers[1], "#list") as output:
			self.assertIn(self.testPhoneNumbers[0], output)

		# ensure that if user 1 creates a handle for user 0 that's used instead
		self.createHandle(self.testPhoneNumbers[1], "@user0", self.testPhoneNumbers[0])
		with capture(views.cliMsg, self.testPhoneNumbers[1], "#list") as output:
			self.assertIn("@user0", output)

	def testShareWithNewUser(self):
		self.createHandle(self.testPhoneNumbers[0], "@test", "6505551111")
		with capture(views.cliMsg, self.testPhoneNumbers[0], "item #list @test") as output:
			self.assertIn("@test", output)

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
		with capture(views.cliMsg, self.testPhoneNumbers[0], "poop #list @test"):
			pass
		with capture(views.cliMsg, self.testPhoneNumbers[0], "delete 1 #list"):
			pass
		with capture(views.cliMsg, self.testPhoneNumbers[1], "#list") as output:
			self.assertNotIn("poop", output)

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
		self.user.save()

	def testSendTips(self):
		self.setupUser(True, True)
		with capture(async.sendTips, constants.SMSKEEPER_TEST_NUM) as output:
			self.assertIn(tips.SMSKEEPER_TIPS[0]["messages"][0], output)

		# set datetime to return a full day ahead after each call
		with Replacer() as r:
			r.replace('smskeeper.async.datetime.datetime', test_datetime(2020, 01, 01))
			# check that tip 2 got sent out
			with capture(async.sendTips, constants.SMSKEEPER_TEST_NUM) as output:
				self.assertIn(tips.SMSKEEPER_TIPS[1]["messages"][0], output)
			r.replace('smskeeper.async.datetime.datetime', datetime.datetime)

	def testTipThrottling(self):
		self.setupUser(True, True)
		with capture(async.sendTips, constants.SMSKEEPER_TEST_NUM):
			pass
		with capture(async.sendTips, constants.SMSKEEPER_TEST_NUM) as output:
			self.assertNotIn(tips.SMSKEEPER_TIPS[1]["messages"][0], output)

	def testTipsSkipIneligibleUsers(self):
		self.setupUser(True, False)
		with capture(async.sendTips, constants.SMSKEEPER_TEST_NUM) as output:
			self.assertNotIn(tips.SMSKEEPER_TIPS[0]["messages"][0], output)

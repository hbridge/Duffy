from django.test import TestCase
import sys
from cStringIO import StringIO
from contextlib import contextmanager
import time

from smskeeper import views, processing_util
from smskeeper.models import User, Entry, Message, MessageMedia, Contact
import datetime
import pytz
from django.conf import settings

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

	def setupUser(self, activated, tutorialComplete):
		self.user, created = User.objects.get_or_create(phone_number=self.testPhoneNumber)
		self.user.completed_tutorial = tutorialComplete
		if (activated):
			self.user.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		self.user.save()

	def test_first_connect(self):
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertTrue("magic phrase" in output, output)

	def test_unactivated_connect(self):
		self.setupUser(False, False)
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertTrue("Nope." in output, output)

	def test_magicphrase(self):
		self.setupUser(False, False)
		with capture(views.cliMsg, self.testPhoneNumber, "trapper keeper") as output:
			self.assertTrue("Let's get started" in output, output)

	def test_tutorial(self):
		self.setupUser(True, False)

		# Activation message asks for their name
		with capture(views.cliMsg, self.testPhoneNumber, "UnitTests") as output:
			self.assertTrue("nice to meet you UnitTests" in output, output)
			self.assertTrue("I can help you create a list" in output, output)
			self.assertTrue(User.objects.get(phone_number=self.testPhoneNumber).name == "UnitTests")

		with capture(views.cliMsg, self.testPhoneNumber, "new5 #test") as output:
			self.assertTrue("Now send me another item for the same list" in output, output)

		with capture(views.cliMsg, self.testPhoneNumber, "new2 #test") as output:
			self.assertTrue("You can send items to this list" in output, output)

		with capture(views.cliMsg, self.testPhoneNumber, "#test") as output:
			self.assertTrue("That's all you need to know for now" in output, output)

	def test_get_label_doesnt_exist(self):
		self.setupUser(True, True)
		with capture(views.cliMsg, self.testPhoneNumber, "#test") as output:
			self.assertTrue("Sorry, I don't" in output, output)

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
			self.assertTrue(views.UNASSIGNED_LABEL in output)
		with capture(views.cliMsg, self.testPhoneNumber, views.UNASSIGNED_LABEL) as output:
			# ensure the user can get things from #unassigned
			self.assertTrue("new" in output, output)

	def test_absolute_delete(self):
		self.setupUser(True, True)
		# ensure deleting from an empty list doesn't crash
		views.cliMsg(self.testPhoneNumber, "delete 1 #test")
		views.cliMsg(self.testPhoneNumber, "old fashioned #cocktail")

		# First make sure that the entry is there
		with capture(views.cliMsg, self.testPhoneNumber, "#cocktail") as output:
			self.assertTrue("old fashioned" in output, output)

		# Next make sure we delete and the list is clear
		views.cliMsg(self.testPhoneNumber, "delete 1 #cocktail") #test absolute delete
		with capture(views.cliMsg, self.testPhoneNumber, "#cocktail") as output:
			self.assertTrue("Sorry, I don't" in output, output)

	def test_contextual_delete(self):
		self.setupUser(True, True)
		for i in range(1, 2):
			views.cliMsg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we don't delete when ambiguous
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertTrue("Sorry, I'm not sure" in output, output)

		# ensure deletes right item
		views.cliMsg(self.testPhoneNumber, "#bar")
		with capture(views.cliMsg, self.testPhoneNumber, "delete 2") as output:
			self.assertTrue("2. foo2" not in output, output)

		# ensure can chain deletes
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertTrue("1. foo1" not in output, output)

		# ensure deleting from empty doesn't crash
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertTrue("no item 1" in output, output)

	def test_reminders_basic(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, "#remind poop tmr") as output:
			self.assertTrue("a day from now" in output, output)

	def test_reminders_remind_works(self):
		self.setupUser(True, True)

		views.cliMsg(self.testPhoneNumber, "#remind poop tmr")
		self.assertTrue("#reminders" in Entry.fetchAllLabels(self.user), Entry.fetchAllLabels(self.user))

	def test_reminders_followup(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, "#remind poop") as output:
			self.assertTrue("what time?" in output, output)

		with capture(views.cliMsg, self.testPhoneNumber, "tomorrow") as output:
			self.assertTrue("a day from now" in output, output)


	"""
		Set a user first the Eastern and make sure it comes back as a utc time for 3 pm Eastern
		Then set the user's timezone to be Pacific and make sure natty returns a time for 3pm Pactific in UTC
	"""
	def test_natty_timezone(self):
		self.setupUser(True, True)
		self.user.timezone = "US/Eastern" # This is the default
		self.user.save()

		views.cliMsg(self.testPhoneNumber, "#remind poop 3pm tomorrow")

		entry = Entry.fetchEntries(user=self.user, label="#reminders")[0]

		self.assertEqual(entry.remind_timestamp.hour, 19) # 3 pm Eastern in UTC

		views.cliMsg(self.testPhoneNumber, "clear #reminders")

		self.user.timezone = "US/Pacific" # This is the default
		self.user.save()
		views.cliMsg(self.testPhoneNumber, "#remind poop 3pm tomorrow")

		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]

		self.assertEqual(entry.remind_timestamp.hour, 22) # 3 pm Pactific in UTC

	def test_state_machine(self):
		commands = processing_util.getPossibleCommands("#test this is a test")
		print "HERE: %s" % commands

class SMSKeeperSharingCase(TestCase):
	testPhoneNumber = "+16505555550"
	handle = "@test"
	targetNum = "6505551111"
	user = None


	def normalizeNumber(self, number):
		return "+1" + number;

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

	def testCreateContact(self):
		self.setupUser(True, True)

		# make sure the output contains the normalized number
		with capture(views.cliMsg, self.testPhoneNumber, "%s %s" % (self.handle, self.targetNum)) as output:
			self.assertTrue(self.normalizeNumber(self.targetNum) in output)

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.user, handle=self.handle)
		self.assertEqual(contact.target.phone_number, self.normalizeNumber(self.targetNum))

		# make sure there's a user for the new contact
		targetUser = User.objects.get(phone_number=self.normalizeNumber(self.targetNum))
		self.assertNotEqual(targetUser, None)

	def testReassignContact(self):
		self.setupUser(True, True)

		# create a user
		with capture(views.cliMsg, self.testPhoneNumber, "%s %s" % (self.handle, "9175555555")) as output:
			pass

		#change it 
		with capture(views.cliMsg, self.testPhoneNumber, "%s %s" % (self.handle, self.targetNum)) as output:
			self.assertTrue(self.normalizeNumber(self.targetNum) in output)

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.user, handle=self.handle)
		self.assertEqual(contact.target.phone_number, self.normalizeNumber(self.targetNum))








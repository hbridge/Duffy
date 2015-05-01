from django.test import TestCase
import sys
from cStringIO import StringIO
from contextlib import contextmanager
import time

from smskeeper import views
from smskeeper.models import User, Note, NoteEntry, Message, MessageMedia



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
		self.user.activated = activated
		self.user.save()

	def test_first_connect(self):
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertTrue("not quite ready" in output)

	def test_unactivated_connect(self):
		self.setupUser(False, False)
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertTrue("You're back!" in output)

	def test_tutorial(self):
		self.setupUser(True, False)

		# Activation message asks for their name
		with capture(views.cliMsg, self.testPhoneNumber, "UnitTests") as output:
			self.assertTrue("nice to meet you UnitTests" in output)
			self.assertTrue("Let's try creating a list" in output)
			self.assertTrue(User.objects.get(phone_number=self.testPhoneNumber).name == "UnitTests")

		with capture(views.cliMsg, self.testPhoneNumber, "new5 #test") as output:
			self.assertTrue("Now let's add another item to your list" in output)

		with capture(views.cliMsg, self.testPhoneNumber, "new2 #test") as output:
			self.assertTrue("You can add items to this list" in output)

		with capture(views.cliMsg, self.testPhoneNumber, "#test") as output:
			self.assertTrue("That should get you started" in output)

	def test_get_label_doesnt_exist(self):
		self.setupUser(True, True)
		with capture(views.cliMsg, self.testPhoneNumber, "#test") as output:
			self.assertTrue("Sorry, I don't" in output)

	def test_get_label(self):
		self.setupUser(True, True)
		views.cliMsg(self.testPhoneNumber, "new #test")
		with capture(views.cliMsg, self.testPhoneNumber, "#test") as output:
			self.assertTrue("new" in output)

	def test_pick_label(self):
		self.setupUser(True, True)
		views.cliMsg(self.testPhoneNumber, "new #test")
		with capture(views.cliMsg, self.testPhoneNumber, "pick #test") as output:
			self.assertTrue("new" in output)

	def test_print_hashtags(self):
		self.setupUser(True, True)
		views.cliMsg(self.testPhoneNumber, "new #test")
		with capture(views.cliMsg, self.testPhoneNumber, "#hashtag") as output:
			self.assertTrue("(1)" in output)

	def test_add_unassigned(self):
		self.setupUser(True, True)
		with capture(views.cliMsg, self.testPhoneNumber, "new") as output:
			# ensure we tell the user we put it in unassigned
			self.assertTrue(views.UNASSIGNED_LABEL in output)
		with capture(views.cliMsg, self.testPhoneNumber, views.UNASSIGNED_LABEL) as output:
			# ensure the user can get things from #unassigned
			self.assertTrue("new" in output)

	def test_absolute_delete(self):
		self.setupUser(True, True)
		# ensure deleting from an empty list doesn't crash
		views.cliMsg(self.testPhoneNumber, "delete 1 #test")
		views.cliMsg(self.testPhoneNumber, "old fashioned #cocktail")
		views.cliMsg(self.testPhoneNumber, "delete 1 #cocktail") #test absolute delete
		with capture(views.cliMsg, self.testPhoneNumber, "#cocktail") as output:
			self.assertTrue("Sorry, I don't" in output)

	def test_contextual_delete(self):
		self.setupUser(True, True)
		for i in range(1, 2):
			views.cliMsg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we don't delete when ambiguous
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertTrue("Sorry, I'm not sure" in output)

		# ensure deletes right item
		views.cliMsg(self.testPhoneNumber, "#bar")
		with capture(views.cliMsg, self.testPhoneNumber, "delete 2") as output:
			self.assertTrue("2. foo2" not in output)

		# ensure can chain deletes
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertTrue("1. foo1" not in output)

		# ensure deleting from empty doesn't crash
		with capture(views.cliMsg, self.testPhoneNumber, "delete 1") as output:
			self.assertTrue("no item 1" in output)

	def test_reminders_basic(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, "#remind poop tmr") as output:
			self.assertTrue("poop a day from now" in output)

	def test_reminders_remind_works(self):
		self.setupUser(True, True)

		views.cliMsg(self.testPhoneNumber, "#remind poop tmr")
		self.assertTrue(Note.objects.filter(user=self.user, label="#reminders").count() == 1)

	def test_reminders_followup(self):
		self.setupUser(True, True)

		with capture(views.cliMsg, self.testPhoneNumber, "#remind poop") as output:
			self.assertTrue("what time?" in output)

		with capture(views.cliMsg, self.testPhoneNumber, "tomorrow") as output:
			self.assertTrue("poop a day from now" in output)





from django.test import TestCase
import sys
from cStringIO import StringIO
from contextlib import contextmanager

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
		user, created = User.objects.get_or_create(phone_number=self.testPhoneNumber)
		user.completed_tutorial = tutorialComplete
		user.activated = activated
		user.save()

	def test_first_connect(self):
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertTrue("Thanks for signing up" in output)

	def test_unactivated_connect(self):
		self.setupUser(False, False)
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertTrue("Thanks for the message" in output)

	def test_tutorial(self):
		self.setupUser(True, False)
		with capture(views.cliMsg, self.testPhoneNumber, "hi") as output:
			self.assertTrue("Hi. I'm Keeper." in output)
			self.assertTrue("Let's try creating a list" in output)
			self.assertTrue(User.objects.filter(phone_number=self.testPhoneNumber).exists())

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
			self.assertTrue(views.UNASSIGNED_LABEL in output)

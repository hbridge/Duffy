import datetime
import pytz
import string
from mock import patch

from testfixtures import Replacer
from testfixtures import test_datetime

from django.test import TestCase

from peanut.settings import constants
from smskeeper.models import User, Entry, Contact, Message, ZipData
from smskeeper import msg_util, cliMsg, keeper_constants
from smskeeper import async
from smskeeper import tips

from common import natty_util

from smskeeper import sms_util


def getOutput(mock):
	output = u""
	for call in mock.call_args_list:
		arg, kargs = call
		output += unicode(arg[0].decode('utf-8'))

	return output


# Set this on a mock's side_effect and it will return the same args that were inputted for any function
def mock_return_input(*args):
	return args[1:]


class SMSKeeperBaseCase(TestCase):
	testPhoneNumber = "+16505555550"
	user = None

	def setUp(self):
		try:
			user = User.objects.get(phone_number=self.testPhoneNumber)
			user.delete()
		except User.DoesNotExist:
			pass

		# Need to do this everytime otherwise if we're doing things in timezones in the code
		# then the database will be empty and default to Eastern
		self.setupZipCodeData()

	def setupZipCodeData(self):
		ZipData.objects.create(city="San Francisco", state="CA", zip_code="94117", timezone="PST", area_code="415")
		ZipData.objects.create(city="Manhattan", state="NY", zip_code="10012", timezone="EST", area_code="212")
		ZipData.objects.create(city="New York", state="NY", zip_code="10012", timezone="EST", area_code="212")

	# TODO(Derek): Eventually activated and tutorialComplete should go away
	def setupUser(self, activated, tutorialComplete, state=keeper_constants.STATE_NORMAL):
		self.user, created = User.objects.get_or_create(phone_number=self.testPhoneNumber)
		self.user.completed_tutorial = tutorialComplete
		if (activated):
			self.user.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		self.user.state = state
		self.user.save()

	def getTestUser(self):
		return User.objects.get(id=self.user.id)

	def getUserNow(self):
		now = datetime.datetime.now(pytz.utc)
		# This could be sped up with caching
		return now.astimezone(self.getTestUser().getTimezone())


class SMSKeeperMainCase(SMSKeeperBaseCase):

	def test_first_connect(self):
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi")
			self.assertIn("I'll be in touch", getOutput(mock))

	def test_unactivated_connect(self):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		cliMsg.msg(self.testPhoneNumber, "hi")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi")
			self.assertIn("", getOutput(mock))

	def test_magicphrase(self):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		cliMsg.msg(self.testPhoneNumber, "trapper keeper")
		user = User.objects.get(phone_number=self.testPhoneNumber)
		self.assertNotEqual(user.state, keeper_constants.STATE_NOT_ACTIVATED)

	def test_tellmemore(self):
		self.setupUser(False, False, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me more")
			self.assertIn(keeper_constants.TELL_ME_MORE, getOutput(mock))

	def test_firstItemAdded(self):
		self.setupUser(False, False, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#groceries milk")
			self.assertIn("Just type 'groceries'", getOutput(mock))

	def test_freeform_add_fetch(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk to groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertIn("milk", getOutput(mock))
			cliMsg.msg(self.testPhoneNumber, "Add spinach to my groceries list")
			cliMsg.msg(self.testPhoneNumber, "what's on my groceries list?")
			self.assertIn("spinach", getOutput(mock))
			cliMsg.msg(self.testPhoneNumber, "add tofu to groceries")
			cliMsg.msg(self.testPhoneNumber, "groceries list")
			self.assertIn("tofu", getOutput(mock))

	def test_freeform_multi_add(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			output = getOutput(mock)
			self.assertIn("milk", output)
			self.assertIn("spinach", output)
			self.assertIn("bread", output)

	def test_add_multi_word_label(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add foo to my bar baz list")
			cliMsg.msg(self.testPhoneNumber, "bar baz")
			output = getOutput(mock)
			self.assertIn("foo", output)

	def test_freeform_clear(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
			cliMsg.msg(self.testPhoneNumber, "Clear groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			output = getOutput(mock)
			self.assertNotIn("milk", output)

	def test_tutorial_list(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_LIST)

		# Activation message asks for their name
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", getOutput(mock))
			self.assertIn("Let me show you the basics", getOutput(mock))
			self.assertEquals(User.objects.get(phone_number=self.testPhoneNumber).name, "UnitTests")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new5 #test")
			self.assertIn("Now let's add other items to your list", getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new2 #test")
			self.assertIn("You can send items to this", getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("You got it", getOutput(mock))

	def test_tutorial_remind_normal(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", getOutput(mock))

		# Activation message asks for their zip
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "10012")
			self.assertIn("Thanks. Let me show you how to set a reminder. Just say", getOutput(mock))
			self.assertEquals(User.objects.get(phone_number=self.testPhoneNumber).name, "UnitTests")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call mom tomorrow")
			correctString = msg_util.naturalize(self.getUserNow(), self.getUserNow() + datetime.timedelta(days=1))
			self.assertIn(correctString, getOutput(mock))
			self.assertIn("I can also help you with other things", getOutput(mock))

	def test_tutorial_remind_no_time_given(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "10012")

		with patch('smskeeper.async.recordOutput') as mock:
			with patch('smskeeper.states.remind.datetime') as datetimeMock:
				# We set the time to be 10 am so we can check the default time later.
				# But need to set early otherwise default could be tomorrow
				datetimeMock.datetime.now.return_value = self.getUserNow().replace(hour=10)
				cliMsg.msg(self.testPhoneNumber, "Remind me to call mom")

				# Since there was no time given, should have picked a time in the near future
				self.assertIn("today at 6pm", getOutput(mock))

				# This is the key here, make sure we have the extra message
				self.assertIn("In the future, you can", getOutput(mock))

	def test_tutorial_remind_time_zones(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call mom")

			# Since there was no time given, should have picked a time in the near future
			self.assertIn("today", getOutput(mock))

			# This is the key here, make sure we have the extra message
			self.assertIn("In the future, you can", getOutput(mock))

	def test_tutorial_zip_code(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		user = self.getTestUser()
		self.assertEqual(user.timezone, "PST")

	def test_get_label_doesnt_exist(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("Sorry, I don't", getOutput(mock))

	def test_get_label(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("new", getOutput(mock))

	def test_pick_label(self):
		self.setupUser(True, True)
		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "pick #test")
			self.assertTrue("new", getOutput(mock))

	def test_print_hashtags(self):
		self.setupUser(True, True)
		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#hashtag")
			self.assertIn("(1)", getOutput(mock))

	def test_unknown_command(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new")
			# ensure we tell the user we don't understand
			self.assertIn(getOutput(mock), keeper_constants.UNKNOWN_COMMAND_PHRASES)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, keeper_constants.REPORT_ISSUE_KEYWORD)
			self.assertIn(keeper_constants.REPORT_ISSUE_CONFIRMATION, getOutput(mock))

	def test_no_add_dumb_stuff(self):
		self.setupUser(True, True)
		dumb_phrases = ["hi", "thanks", "no", "yes", "thanks, keeper!", "cool", "OK"]

		for phrase in dumb_phrases:
			with patch('smskeeper.async.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, phrase)
				output = getOutput(mock)
				self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES, "nicety not detected: %s" % (phrase))

	def test_absolute_delete(self):
		self.setupUser(True, True)
		# ensure deleting from an empty list doesn't crash
		cliMsg.msg(self.testPhoneNumber, "delete 1 #test")
		cliMsg.msg(self.testPhoneNumber, "old fashioned #cocktail")

		# First make sure that the entry is there
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertIn("old fashioned", getOutput(mock))

		# Next make sure we delete and the list is clear
		cliMsg.msg(self.testPhoneNumber, "delete 1 #cocktail")   # test absolute delete
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertIn("Sorry, I don't", getOutput(mock))

	def test_contextual_delete(self):
		self.setupUser(True, True)
		for i in range(1, 2):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we don't delete when ambiguous
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertIn("Sorry, I'm not sure", getOutput(mock))

		# ensure deletes right item
		cliMsg.msg(self.testPhoneNumber, "#bar")
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 2")
			self.assertNotIn("2. foo2", getOutput(mock))

		# ensure can chain deletes
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("1. foo1", getOutput(mock))

		# ensure deleting from empty doesn't crash
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("I deleted", getOutput(mock))

	def test_multi_delete(self):
		self.setupUser(True, True)
		for i in range(1, 5):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we can delete with or without spaces
		cliMsg.msg(self.testPhoneNumber, "delete 3, 5,2 #bar")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#bar")

			self.assertNotIn("foo2", getOutput(mock))
			self.assertNotIn("foo3", getOutput(mock))
			self.assertNotIn("foo5", getOutput(mock))

	def test_reminders_basic(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop tmr")
			self.assertIn("tomorrow", getOutput(mock))

		self.assertIn("#reminders", Entry.fetchAllLabels(self.user))

	def test_reminders_no_hashtag(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to poop tmr")
			self.assertNotIn("remind me to", getOutput(mock))
			self.assertIn("tomorrow", getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "reminders")
			self.assertIn("poop", getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "clear reminders")
			cliMsg.msg(self.testPhoneNumber, "reminders")
			self.assertNotIn("poop", getOutput(mock))

	# This test is here to make sure the ordering of fetch vs reminders is correct
	def test_reminders_fetch(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#reminders")
			self.assertIn("#reminders", getOutput(mock))

	def test_reminders_followup_change(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop")
			self.assertIn("If that time doesn't work", getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tomorrow")
			self.assertIn("tomorrow", getOutput(mock))

	def test_reminders_two_in_row(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop")
			self.assertIn("If that time doesn't work", getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind pee tomorrow")
			cliMsg.msg(self.testPhoneNumber, "#remind")
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
				with patch('smskeeper.async.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 6 pm, so 9 hours
					self.assertIn("today at 6pm", getOutput(mock))

				# Try with 3 pm EST
				testDt = test_datetime(2020, 01, 01, 15, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = testDt.utcnow()
				with patch('smskeeper.async.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 9 pm, so 6 hours
					self.assertIn("today at 9pm", getOutput(mock))

				# Try with 10 pm EST
				testDt = test_datetime(2020, 01, 01, 22, 0, 0, tzinfo=tz)
				r.replace('smskeeper.states.remind.datetime.datetime', testDt)
				mocked.return_value = testDt.utcnow()
				with patch('smskeeper.async.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, "#remind poop")
					# Should be 9 am next day, so in 11 hours
					self.assertIn("tomorrow at 9am", getOutput(mock))

			r.replace('smskeeper.states.remind.datetime.datetime', datetime.datetime)

	def test_reminders_commas(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, "remind me to poop, then poop again")

		entry = Entry.objects.get(label="#reminders")

		self.assertIn("poop, then poop again", entry.text)

	def test_naturalize(self):
		# Sunday, May 31 at 8 am
		now = datetime.datetime(2015, 05, 31, 8, 0, 0)

		# Later today
		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 9, 0, 0))
		self.assertIn("today at 9am", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 15, 0, 0))
		self.assertIn("today at 3pm", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 15, 5, 0))
		self.assertIn("today at 3:05pm", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 15, 45, 0))
		self.assertIn("today at 3:45pm", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 23, 45, 0))
		self.assertIn("today at 11:45pm", ret)

		# Tomorrow
		ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 1, 2, 0, 0))
		self.assertIn("tomorrow at 2am", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 1, 15, 0, 0))
		self.assertIn("tomorrow at 3pm", ret)

		# Day of week (this week)
		ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 2, 15, 0, 0))
		self.assertIn("Tue at 3pm", ret)

		# date of week (next week)
		ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 7, 15, 0, 0))
		self.assertIn("next Sun at 3pm", ret)

		# far out
		with patch('humanize.time._now') as mocked:
			mocked.return_value = now

			ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 14, 15, 0, 0))
			self.assertIn("14 days from now", ret)

	def test_exception_error_message(self):
		self.setupUser(True, True)
		with self.assertRaises(NameError):
			cliMsg.msg(self.testPhoneNumber, 'yippee ki yay motherfucker')

		# we have to dig into messages as ouput would never get returned from the mock
		messages = Message.objects.filter(user=self.user, incoming=False).all()
		self.assertIn(messages[0].getBody(), keeper_constants.GENERIC_ERROR_MESSAGES)

	def test_unicode_msg(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, u'poop\u2019s tmr #unitest')
			cliMsg.msg(self.testPhoneNumber, u'#unitest')
			self.assertIn(u'poop\u2019s tmr', getOutput(mock))

	def testSendMsgs(self):
		self.setupUser(True, True)
		with self.assertRaises(TypeError):
			sms_util.sendMsgs(self.user, "hello", constants.SMSKEEPER_TEST_NUM)
		with self.assertRaises(TypeError):
			sms_util.sendMsg(self.user, ["hello", "this is the wrong type"], None, constants.SMSKEEPER_TEST_NUM)

	def testPhotoWithoutTag(self):
		self.setupUser(True, True)

		with patch('smskeeper.image_util.moveMediaToS3') as moveMediaMock:
			# moveMediaMock.return_value = ["hello"]
			moveMediaMock.side_effect = mock_return_input
			with patch('smskeeper.async.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")
				# ensure we don't treat photos without a hashtag as a bad command
				output = getOutput(mock)
				self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES)
				self.assertIn(keeper_constants.PHOTO_LABEL, output)

		# make sure the entry got created
		Entry.objects.get(label=keeper_constants.PHOTO_LABEL)

	def testScreenshotWithoutTag(self):
		self.setupUser(True, True)

		with patch('smskeeper.image_util.moveMediaToS3') as moveMediaMock:
			# moveMediaMock.return_value = ["hello"]
			moveMediaMock.side_effect = mock_return_input
			with patch('smskeeper.async.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.png", mediaType="image/png")
				# ensure we don't treat photos without a hashtag as a bad command
				output = getOutput(mock)
				self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES)
				self.assertIn(keeper_constants.SCREENSHOT_LABEL, output)

		# make sure the entry got created
		Entry.objects.get(label=keeper_constants.SCREENSHOT_LABEL)

	def testSetNameFirstTimeEasy(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)
		cliMsg.msg(self.testPhoneNumber, "Foo Bar")
		self.user = User.objects.get(id=self.user.id)
		self.assertEqual(self.user.name, "Foo Bar")

	def testSetNameFirstTimePhrase(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)
		cliMsg.msg(self.testPhoneNumber, "My name is Foo Bar")
		self.user = User.objects.get(id=self.user.id)
		self.assertEqual(self.user.name, "Foo Bar")

	def testSetNameLater(self):
		self.setupUser(True, True)
		cliMsg.msg(self.testPhoneNumber, "My name is Foo Bar")
		self.user = User.objects.get(id=self.user.id)
		self.assertEqual(self.user.name, "Foo Bar")


class SMSKeeperNattyCase(SMSKeeperBaseCase):

	def test_unicode_natty(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, u'#remind poop\u2019s tmr')

		entry = Entry.fetchEntries(user=self.user, label="#reminders")[0]
		self.assertIn(u'poop\u2019s', entry.text)

	# Set a user first the Eastern and make sure it comes back as a utc time for 3 pm Eastern
	# Then set the user's timezone to be Pacific and make sure natty returns a time for 3pm Pactific in UTC
	def test_natty_timezone(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#remind poop 3pm tomorrow")

		entry = Entry.fetchEntries(user=self.user, label="#reminders")[0]

		self.assertEqual(entry.remind_timestamp.hour, 19)  # 3 pm Eastern in UTC

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "clear #reminders")
			self.assertIn("cleared", getOutput(mock))

		self.user.timezone = "PST-2"  # This is not the default
		self.user.save()
		cliMsg.msg(self.testPhoneNumber, "#remind poop 1pm tomorrow")

		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]

		self.assertEqual(entry.remind_timestamp.hour, 23)  # 1 pm Hawaii in UTC

	def test_natty_two_times_by_words(self):
		self.setupUser(True, True)

		inTwoHours = self.getUserNow() + datetime.timedelta(hours=2)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#reminder book meeting with Andrew for tues morning in two hours")
			correctString = msg_util.naturalize(self.getUserNow(), inTwoHours)
			self.assertIn(correctString, getOutput(mock))

	def test_natty_two_times_by_number(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			inFourHours = self.getUserNow() + datetime.timedelta(hours=4)

			cliMsg.msg(self.testPhoneNumber, "#remind change archie grade to 2 in 4 hours")
			correctString = msg_util.naturalize(self.getUserNow(), inFourHours)
			self.assertIn(correctString, getOutput(mock))

			entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]
			self.assertIn("change archie grade to 2", entry.text)

		with patch('smskeeper.async.recordOutput') as mock:
			inFiveHours = self.getUserNow() + datetime.timedelta(hours=5)

			cliMsg.msg(self.testPhoneNumber, "#remind change bobby grade to 10 in 5 hours")
			correctString = msg_util.naturalize(self.getUserNow(), inFiveHours)
			self.assertIn(correctString, getOutput(mock))

			entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[1]
			self.assertIn("change bobby grade to 10", entry.text)

	# If its 12:30 and I say "change grade to 12 at 12", it should return back midnight
	def test_natty_just_number_behind_now(self):
		self.setupUser(True, True)

		now = datetime.datetime.now(self.user.getTimezone())
		correctTime = now + datetime.timedelta(hours=12)
		query = "#remind change susie grade to 12 at %s" % now.hour

		cliMsg.msg(self.testPhoneNumber, query)

		entries = Entry.fetchEntries(self.user, "#reminders")
		self.assertEqual(len(entries), 1)
		entry = entries[0]

		remindTime = entry.remind_timestamp.astimezone(self.user.getTimezone())
		self.assertEqual(remindTime.hour, correctTime.hour)

		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]
		self.assertIn("change susie grade to 12", entry.text)

	def test_natty_get_new_query(self):
		ret = natty_util.getNewQuery("at 10", "at 10", 1)
		self.assertEqual(ret, "")

		ret = natty_util.getNewQuery("blah at 10", "at 10", 6)
		self.assertEqual(ret, "blah")

		ret = natty_util.getNewQuery("at 10 I want pizza", "at 10", 1)
		self.assertEqual(ret, "I want pizza")

		ret = natty_util.getNewQuery("I want pizza at 10 so yummy", "at 10", 14)
		self.assertEqual(ret, "I want pizza so yummy")

	def test_natty_user_queries(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, "#remind to cancel Saturday, 5/30 class this Friday at 2pm")
		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]
		self.assertEqual(entry.remind_timestamp.hour, 18)  # 2pm Eastern in UTC

		cliMsg.msg(self.testPhoneNumber, "clear #reminders")

		cliMsg.msg(self.testPhoneNumber, "#remind change archie grade to 23 at 8pm tomorrow")
		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]
		self.assertEqual(entry.remind_timestamp.hour, 0)  # 8pm Eastern in UTC

	def testPausedState(self):
		self.setupUser(True, True, keeper_constants.STATE_PAUSED)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#reminders")
			output = getOutput(mock)
			self.assertIs(u'', output)


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
		with patch('smskeeper.async.recordOutput') as mock:
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
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.nonUserNumber))
			self.assertIn(self.normalizeNumber(self.nonUserNumber), getOutput(mock))

		# make sure there's a user for the new contact
		targetUser = User.objects.get(phone_number=self.normalizeNumber(self.nonUserNumber))
		self.assertNotEqual(targetUser, None)

	def testReassignContact(self):
		# create a contact
		cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[1]))

		# change it
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "%s %s" % (self.handle, self.testPhoneNumbers[2]))
			self.assertIn(self.testPhoneNumbers[2], getOutput(mock))

		# ensure the contact has the right number
		contact = Contact.objects.get(user=self.users[0], handle=self.handle)
		self.assertEqual(contact.target.phone_number, self.testPhoneNumbers[2])

	def testShareWithExsitingUser(self):
		self.createHandle(self.testPhoneNumbers[0], "@test", self.testPhoneNumbers[1])
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "item #list @test")
			self.assertIn("@test", getOutput(mock))

		# ensure that the phone number for user 0 is listed in #list for user 1
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[1], "#list")
			self.assertIn(self.testPhoneNumbers[0], getOutput(mock))

		# ensure that if user 1 creates a handle for user 0 that's used instead
		self.createHandle(self.testPhoneNumbers[1], "@user0", self.testPhoneNumbers[0])
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[1], "#list")
			self.assertIn("@user0", getOutput(mock))

	def testShareWithNewUser(self):
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumbers[0], "item #list @test")
			self.assertIn("@test", getOutput(mock))
			cliMsg.msg(self.testPhoneNumbers[0], "6505551111")

			# Make sure that the intro message was sent out to the new user
			self.assertIn("Hi there.", getOutput(mock))
		with patch('smskeeper.async.recordOutput') as mock:
			# make sure that the entry was actually shared with @test
			cliMsg.msg(self.testPhoneNumbers[0], "#list")
			self.assertIn("@test", getOutput(mock))

		# make sure the item is in @test's lists
		# do an actual entry fetch because the text responses for the user will be unactivated stuff etc
		newUser = User.objects.get(phone_number=self.normalizeNumber("6505551111"))
		entries = Entry.fetchEntries(newUser, "#list")
		self.assertEqual(len(entries), 1)

	# TODO(Henry) add test case for sharing with handle resolution
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
			self.assertNotIn("poop", getOutput(mock))


def setMockDatetimeDaysAhead(mock, days, customHour=None, customTimeZone=None):
	dt = datetime.datetime.now(pytz.utc) + datetime.timedelta(days)
	if customHour is not None:
		dt = dt.replace(hour=customHour)
	if customTimeZone is not None:
		dt = dt.replace(tzinfo=customTimeZone)
	mock.datetime.now.return_value = dt
	mock.date.side_effect = lambda *args, **kw: datetime.date(*args, **kw)
	mock.datetime.side_effect = lambda *args, **kw: datetime.datetime(*args, **kw)


def setMockDatetimeToSendTip(mock):
	setMockDatetimeDaysAhead(mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS, tips.SMSKEEPER_TIP_HOUR)

class SMSKeeperAsyncCase(SMSKeeperBaseCase):
	def setupUser(self, activated, tutorialComplete, timezoneString):
		SMSKeeperBaseCase.setupUser(self, activated, tutorialComplete)
		self.user.timezone = timezoneString  # put the user in UTC by default, makes most tests easier
		self.user.save()

	def testSendTipTimezones(self):
		self.setupUser(True, True, "EST")
		self.user.timezone = "EST"  # put the user in EST to test our tz conversion
		self.user.save()

		with patch('smskeeper.tips.datetime') as datetime_mock:
			# make sure we don't send at the wrong time,
			setMockDatetimeDaysAhead(datetime_mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS + 1, 0, self.user.getTimezone())
			with patch('smskeeper.async.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user.name), getOutput(mock))
		with patch('smskeeper.tips.datetime') as datetime_mock:
			# make sure we do send at the right time!
			setMockDatetimeDaysAhead(datetime_mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS + 1, tips.SMSKEEPER_TIP_HOUR, self.user.getTimezone())
			with patch('smskeeper.async.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[0].render(self.user.name), getOutput(mock))


	def testSendTips(self):
		self.setupUser(True, True, "UTC")

		with patch('smskeeper.tips.datetime') as datetime_mock:
			# make sure we don't send at the wrong time
			setMockDatetimeToSendTip(datetime_mock)
			with patch('smskeeper.async.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[0].render(self.user.name), getOutput(mock))

			# ensure tip 2 gets sent out
			setMockDatetimeDaysAhead(datetime_mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * 2, tips.SMSKEEPER_TIP_HOUR)
			with patch('smskeeper.async.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[1].render(self.user.name), getOutput(mock))

	def testTipThrottling(self):
		self.setupUser(True, True, "UTC")

		with patch('smskeeper.tips.datetime') as datetime_mock:
			# send a tip
			setMockDatetimeToSendTip(datetime_mock)
			async.sendTips(constants.SMSKEEPER_TEST_NUM)

			setMockDatetimeDaysAhead(datetime_mock, (keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * 2) - 1, tips.SMSKEEPER_TIP_HOUR)
			with patch('smskeeper.async.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotIn(tips.SMSKEEPER_TIPS[1].render(self.user.name), getOutput(mock))

	def testTipsSkipIneligibleUsers(self):
		# unactivated users don't get tips
		self.setupUser(True, False, "UTC")
		with patch('smskeeper.tips.datetime') as datetime_mock:
			# send a tip
			setMockDatetimeToSendTip(datetime_mock)
			with patch('smskeeper.async.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user.name), getOutput(mock))

		self.setupUser(True, True, "UTC")
		# user just activated don't send tip
		with patch('smskeeper.async.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user.name), getOutput(mock))

	def testSetTipFrequency(self):
		self.setupUser(True, True, "UTC")
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "send me tips monthly")
			# must reload the user or get a stale value for tip_frequency_days
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.tip_frequency_days, 30, "%s \n user.tip_frequency_days: %d" % (getOutput(mock), self.user.tip_frequency_days))

		with patch('smskeeper.tips.datetime') as datetime_mock:
			setMockDatetimeDaysAhead(datetime_mock, 7, tips.SMSKEEPER_TIP_HOUR)
			# make sure we don't send them in 7 days
			with patch('smskeeper.async.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user.name), getOutput(mock))

			# make sure we do send them in 31 days
			setMockDatetimeDaysAhead(datetime_mock, 31, tips.SMSKEEPER_TIP_HOUR)
			with patch('smskeeper.async.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[0].render(self.user.name), getOutput(mock))

	def testReminderTipRelevance(self):
		self.setupUser(True, True, "UTC")
		with patch('smskeeper.async.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "#reminder test tomorrow")  # set a reminder
			self.assertTipIdNotSent(tips.REMINDER_TIP_ID)

	def testPhotoTipRelevance(self):
		self.setupUser(True, True, "UTC")

		with patch('smskeeper.image_util.moveMediaToS3') as moveMediaMock:
			moveMediaMock.side_effect = mock_return_input
			with patch('smskeeper.async.recordOutput'):
				cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")  # add a photo
				self.assertTipIdNotSent(tips.PHOTOS_TIP_ID)

		with patch('smskeeper.async.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "#reminder test tomorrow")  # set a reminder
			self.assertTipIdNotSent(tips.REMINDER_TIP_ID)

	def testShareTipRelevance(self):
		self.setupUser(True, True, "UTC")
		with patch('smskeeper.async.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "foo #bar @baz")  # share something
			cliMsg.msg(self.testPhoneNumber, "9175551234")  # share something
			self.assertTipIdNotSent(tips.SHARING_TIP_ID)

	def assertTipIdNotSent(self, tipId):
		for i, tip in enumerate(tips.SMSKEEPER_TIPS):
			with patch('smskeeper.tips.datetime') as datetime_mock:
				setMockDatetimeDaysAhead(datetime_mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * (i + 1), tips.SMSKEEPER_TIP_HOUR)
				tip = tips.selectNextTip(self.user)
				if tip:
					self.assertNotEqual(tip.id, tipId)
					tips.markTipSent(self.user, tip)

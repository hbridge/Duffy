import datetime
import pytz
import string
from mock import patch

from django.test import TestCase
from django.conf import settings

from peanut.settings import constants
from smskeeper.models import User, Entry, Contact, Message, ZipData
from smskeeper import msg_util, cliMsg, keeper_constants
from smskeeper import async
from smskeeper import tips

from common import natty_util

from smskeeper import sms_util

import test_base


class SMSKeeperMiscCase(test_base.SMSKeeperBaseCase):

	def test_first_connect(self):
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi")
			self.assertIn("Want seamless organization now", self.getOutput(mock))

	def test_unactivated_connect(self):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		cliMsg.msg(self.testPhoneNumber, "hi")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi")
			self.assertIn("", self.getOutput(mock))

	def test_magicphrase(self):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		cliMsg.msg(self.testPhoneNumber, "trapper keeper")
		user = User.objects.get(phone_number=self.testPhoneNumber)
		self.assertNotEqual(user.state, keeper_constants.STATE_NOT_ACTIVATED)

	def test_tellmemore(self):
		self.setupUser(False, False, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "tell me more")
			self.assertIn(keeper_constants.TELL_ME_MORE, self.getOutput(mock))

	def test_firstItemAdded(self):
		self.setupUser(False, False, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#groceries milk")
			self.assertIn("Just type 'groceries'", self.getOutput(mock))

	def test_freeform_add_fetch(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk to groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertIn("milk", self.getOutput(mock))
			cliMsg.msg(self.testPhoneNumber, "Add spinach to my groceries list")
			cliMsg.msg(self.testPhoneNumber, "what's on my groceries list?")
			self.assertIn("spinach", self.getOutput(mock))
			cliMsg.msg(self.testPhoneNumber, "add tofu to groceries")
			cliMsg.msg(self.testPhoneNumber, "groceries list")
			self.assertIn("tofu", self.getOutput(mock))

	def test_freeform_add_punctuation(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk to groceries.")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertIn("milk", self.getOutput(mock))

	def test_freeform_multi_add(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			output = self.getOutput(mock)
			self.assertIn("milk", output)
			self.assertIn("spinach", output)
			self.assertIn("bread", output)

	def test_add_multi_word_label(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add foo to my bar baz list")
			cliMsg.msg(self.testPhoneNumber, "bar baz")
			output = self.getOutput(mock)
			self.assertIn("foo", output)

	def test_freeform_clear(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
			cliMsg.msg(self.testPhoneNumber, "Clear groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			output = self.getOutput(mock)
			self.assertNotIn("milk", output)

	def test_freeform_delete(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)

		cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
		cliMsg.msg(self.testPhoneNumber, "Groceries")
		cliMsg.msg(self.testPhoneNumber, "Delete 1")
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertNotIn("milk", self.getOutput(mock))


	def test_freeform_fetch_common_list(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "groceries")
			self.assertNotIn(self.getOutput(mock), keeper_constants.UNKNOWN_COMMAND_PHRASES)

	def test_freeform_add_photo(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "add to foo", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")
			# ensure we don't treat photos without a hashtag as a bad command
			output = self.getOutput(mock)
			self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES)

		# make sure the entry got created
		Entry.objects.get(label="#foo")

	def test_freeform_malformed_add(self):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "add to groceries")
			self.assertNotIn(self.getOutput(mock), keeper_constants.ACKNOWLEDGEMENT_PHRASES)


	def test_tutorial_list(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_LIST)

		# Activation message asks for their name
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I'm UnitTests")
			self.assertIn("nice to meet you UnitTests!", self.getOutput(mock))
			self.assertIn("Let me show you the basics", self.getOutput(mock))
			self.assertEquals(User.objects.get(phone_number=self.testPhoneNumber).name, "UnitTests")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new5 #test")
			self.assertIn("Now let's add other items to your list", self.getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new2 #test")
			self.assertIn("You can send items to this", self.getOutput(mock))

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("You got it", self.getOutput(mock))

	def test_tutorial_remind_normal(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", self.getOutput(mock))

		# Activation message asks for their zip
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "10012")
			self.assertIn("Thanks. Let me show you how to set a reminder. Just say", self.getOutput(mock))
			self.assertEquals(User.objects.get(phone_number=self.testPhoneNumber).name, "UnitTests")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call mom tomorrow")
			correctString = msg_util.naturalize(self.getUserNow(), self.getUserNow() + datetime.timedelta(days=1))
			self.assertIn(correctString, self.getOutput(mock))
			self.assertIn("I can also help you with other things", self.getOutput(mock))

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
				self.assertIn("today at 6pm", self.getOutput(mock))

				# This is the key here, make sure we have the extra message
				self.assertIn("In the future, you can", self.getOutput(mock))

	def test_tutorial_remind_time_zones(self):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_REMIND)

		# Activation message asks for their name
		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "94117")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to call mom")

			# Since there was no time given, should have picked a time in the near future
			self.assertIn("today", self.getOutput(mock))

			# This is the key here, make sure we have the extra message
			self.assertIn("In the future, you can", self.getOutput(mock))

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
			self.assertIn("don't have anything", self.getOutput(mock))

	def test_get_label(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("new", self.getOutput(mock))

	def test_pick_label(self):
		self.setupUser(True, True)
		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "pick #test")
			self.assertTrue("new", self.getOutput(mock))

	def test_print_hashtags(self):
		self.setupUser(True, True)
		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#hashtag")
			self.assertIn("(1)", self.getOutput(mock))

	def test_unknown_command(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "new")
			# ensure we tell the user we don't understand
			self.assertIn(self.getOutput(mock), keeper_constants.UNKNOWN_COMMAND_PHRASES)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, keeper_constants.REPORT_ISSUE_KEYWORD)
			self.assertIn(keeper_constants.REPORT_ISSUE_CONFIRMATION, self.getOutput(mock))

	# See if we get into the paused state when we enter an invalid command during daytime hours
	def test_sets_paused_when_daytime(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			with patch('smskeeper.states.normal.datetime') as datetimeMock:
				# Set us to middle of the day so we get paused
				self.assertEqual(self.getTestUser().state, keeper_constants.STATE_NORMAL)
				datetimeMock.datetime.now.return_value = datetime.datetime.now(pytz.timezone("US/Eastern")).replace(hour=12)
				cliMsg.msg(self.testPhoneNumber, "new", cli=True)
				# ensure we got paused
				self.assertEqual(self.getTestUser().state, keeper_constants.STATE_PAUSED)

				# And that we got no response
				self.assertEqual("", self.getOutput(mock))

	# See if we get error message when its night
	def test_sets_paused_when_night(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			with patch('smskeeper.states.normal.datetime') as datetimeMock:
				# set to night time
				datetimeMock.datetime.now.return_value = datetime.datetime.now(pytz.timezone("US/Eastern")).replace(hour=1)
				cliMsg.msg(self.testPhoneNumber, "new", cli=True)
				# ensure we didn't get paused
				self.assertEqual(self.getTestUser().state, keeper_constants.STATE_UNKNOWN_COMMAND)

				# And that we got a response
				self.assertNotEqual("", self.getOutput(mock))


	def test_common_niceties(self):
		self.setupUser(True, True)
		dumb_phrases = ["hi", "thanks", "no", "yes", "thanks, keeper!", "cool", "OK", u"\U0001F44D"]

		for phrase in dumb_phrases:
			with patch('smskeeper.async.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, phrase)
				output = self.getOutput(mock)
				self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES, "nicety not detected: %s" % (phrase))

	def test_thanks_upsell(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks")
			output = self.getOutput(mock)
			self.assertIn(keeper_constants.SHARE_UPSELL_PHRASE, output)

		# make sure we don't send it immediately after
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks")
			output = self.getOutput(mock)
			self.assertNotIn(keeper_constants.SHARE_UPSELL_PHRASE, output)

		# make sure we do send if the last share date was more than SHARE_UPSELL_FREQ prior
		self.user.last_share_upsell = datetime.datetime.now(pytz.utc) - datetime.timedelta(
			days=keeper_constants.SHARE_UPSELL_FREQUENCY_DAYS
		)
		self.user.save()
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks")
			output = self.getOutput(mock)
			self.assertIn(keeper_constants.SHARE_UPSELL_PHRASE, output)



	def test_absolute_delete(self):
		self.setupUser(True, True)
		# ensure deleting from an empty list doesn't crash
		cliMsg.msg(self.testPhoneNumber, "delete 1 #test")
		cliMsg.msg(self.testPhoneNumber, "old fashioned #cocktail")

		# First make sure that the entry is there
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertIn("old fashioned", self.getOutput(mock))

		# Next make sure we delete and the list is clear
		cliMsg.msg(self.testPhoneNumber, "delete 1 #cocktail")   # test absolute delete
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertNotIn("old fashioned", self.getOutput(mock))

	def test_contextual_delete(self):
		self.setupUser(True, True)
		for i in range(1, 2):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we don't delete when ambiguous
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertIn("Sorry, I'm not sure", self.getOutput(mock))

		# ensure deletes right item
		cliMsg.msg(self.testPhoneNumber, "#bar")
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 2")
			self.assertNotIn("2. foo2", self.getOutput(mock))

		# ensure can chain deletes
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("1. foo1", self.getOutput(mock))

		# ensure deleting from empty doesn't crash
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("I deleted", self.getOutput(mock))

	def test_multi_delete(self):
		self.setupUser(True, True)
		for i in range(1, 5):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we can delete with or without spaces
		cliMsg.msg(self.testPhoneNumber, "delete 3, 5,2 #bar")

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#bar")

			self.assertNotIn("foo2", self.getOutput(mock))
			self.assertNotIn("foo3", self.getOutput(mock))
			self.assertNotIn("foo5", self.getOutput(mock))

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
			self.assertIn(u'poop\u2019s tmr', self.getOutput(mock))

	def testSendMsgs(self):
		self.setupUser(True, True)
		with self.assertRaises(TypeError):
			sms_util.sendMsgs(self.user, "hello", constants.SMSKEEPER_TEST_NUM)
		with self.assertRaises(TypeError):
			sms_util.sendMsg(self.user, ["hello", "this is the wrong type"], None, constants.SMSKEEPER_TEST_NUM)

	def testPhotoWithoutTag(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")
			# ensure we don't treat photos without a hashtag as a bad command
			output = self.getOutput(mock)
			self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES)
			self.assertIn(keeper_constants.PHOTO_LABEL, output)

		# make sure the entry got created
		Entry.objects.get(label=keeper_constants.PHOTO_LABEL)

	def testScreenshotWithoutTag(self):
		self.setupUser(True, True)

		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.png", mediaType="image/png")
			# ensure we don't treat photos without a hashtag as a bad command
			output = self.getOutput(mock)
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

	def testSetZipcodeLater(self):
		self.setupUser(True, True)
		self.assertNotEqual(self.user.timezone, "PST")
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "My zipcode is 94117")
			self.assertIn(self.getOutput(mock), keeper_constants.ACKNOWLEDGEMENT_PHRASES)
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.timezone, "PST")
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "My zip code is 10012")
			self.assertIn(self.getOutput(mock), keeper_constants.ACKNOWLEDGEMENT_PHRASES)
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.timezone, "EST")
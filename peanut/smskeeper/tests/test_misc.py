import datetime
from mock import patch

from peanut.settings import constants
from smskeeper.models import User
from smskeeper import msg_util, cliMsg, keeper_constants, sms_util
from common import date_util
from django.conf import settings

import pytz
import test_base
import emoji


@patch('common.date_util.utcnow')
class SMSKeeperMiscCase(test_base.SMSKeeperBaseCase):

	def test_first_connect_product0(self, dateMock):
		self.setNow(dateMock, self.TUE_8AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi", keeperNumber=settings.KEEPER_NUMBER_DICT[0])
			self.assertIn("what's your name?", self.getOutput(mock))

		user = User.objects.get(phone_number=self.testPhoneNumber)
		self.assertEqual(keeper_constants.TODO_PRODUCT_ID, user.product_id)

	def test_first_connect_product1(self, dateMock):
		self.setNow(dateMock, self.TUE_8AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi", keeperNumber=settings.KEEPER_NUMBER_DICT[1])
			self.assertIn("what's your name?", self.getOutput(mock))

		user = User.objects.get(phone_number=self.testPhoneNumber)
		self.assertEqual(keeper_constants.TODO_PRODUCT_ID, user.product_id)

	def test_send_delayed(self, dateMock):
		self.setupUser(True, True)
		sms_util.sendDelayedMsg(self.getTestUser(), "hi", 1, None, classification="testclass")
		self.assertTrue(self.getTestUser().wasRecentlySentMsgOfClass("testclass"))

	"""
	Commented out by Derek while we experiement with no not-activated state
	def test_unactivated_connect(self, dateMock):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		cliMsg.msg(self.testPhoneNumber, "hi")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "hi")
			self.assertIn("", self.getOutput(mock))

	def test_magicphrase(self, dateMock):
		self.setupUser(False, False, keeper_constants.STATE_NOT_ACTIVATED)
		cliMsg.msg(self.testPhoneNumber, "trapper keeper")
		user = User.objects.get(phone_number=self.testPhoneNumber)
		self.assertNotEqual(user.state, keeper_constants.STATE_NOT_ACTIVATED)
	"""
	"""
	def test_firstItemAdded(self, dateMock):
		self.setupUser(False, False, keeper_constants.STATE_NORMAL, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#groceries milk")
			self.assertIn("Just type 'groceries'", self.getOutput(mock))

	def test_freeform_add_fetch(self, dateMock):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk to groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertIn("milk", self.getOutput(mock))
			cliMsg.msg(self.testPhoneNumber, "Add spinach to my groceries list")
			cliMsg.msg(self.testPhoneNumber, "groceries list")
			self.assertIn("spinach", self.getOutput(mock))
			cliMsg.msg(self.testPhoneNumber, "add tofu to groceries")
			cliMsg.msg(self.testPhoneNumber, "groceries list")
			self.assertIn("tofu", self.getOutput(mock))

	def test_freeform_add_punctuation(self, dateMock):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL, dateMock=dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk to groceries.")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertIn("milk", self.getOutput(mock))

	def test_freeform_multi_add(self, dateMock):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			output = self.getOutput(mock)
			self.assertIn("milk", output)
			self.assertIn("spinach", output)
			self.assertIn("bread", output)

	def test_add_multi_word_label(self, dateMock):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add foo to my bar baz list")
			cliMsg.msg(self.testPhoneNumber, "bar baz")
			output = self.getOutput(mock)
			self.assertIn("foo", output)

	def test_freeform_clear(self, dateMock):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
			cliMsg.msg(self.testPhoneNumber, "Clear groceries")
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			output = self.getOutput(mock)
			self.assertNotIn("milk", output)

	def test_freeform_delete(self, dateMock):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL, dateMock=dateMock)

		cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
		cliMsg.msg(self.testPhoneNumber, "Groceries")
		cliMsg.msg(self.testPhoneNumber, "Delete 1")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Groceries")
			self.assertNotIn("milk", self.getOutput(mock))

	def test_freeform_fetch_common_list(self, dateMock):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL, dateMock=dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "groceries")
			self.assertNotIn(self.getOutput(mock), keeper_constants.UNKNOWN_COMMAND_PHRASES)

	def test_freeform_add_photo(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "add to foo", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")
			# ensure we don't treat photos without a hashtag as a bad command
			output = self.getOutput(mock)
			self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES)

		# make sure the entry got created
		Entry.objects.get(label="#foo")

	def test_freeform_malformed_add(self, dateMock):
		self.setupUser(True, True, keeper_constants.STATE_NORMAL, dateMock=dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "add to groceries")
			self.assertNotIn(self.getOutput(mock), keeper_constants.ACKNOWLEDGEMENT_PHRASES)

	def test_get_label_doesnt_exist(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("don't have anything", self.getOutput(mock))

	def test_get_label(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#test")
			self.assertIn("new", self.getOutput(mock))

	def test_pick_label(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "pick #test")
			self.assertTrue("new", self.getOutput(mock))


	def test_print_hashtags(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		cliMsg.msg(self.testPhoneNumber, "new #test")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#hashtag")
			self.assertIn("(1)", self.getOutput(mock))
	"""
	# See if we get into the paused state when we enter an invalid command during daytime hours
	def test_ignore_one_word(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		# Set us to middle of the day so we get paused
		self.setNow(dateMock, self.TUE_3PM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "blah")
			# And that we got no response
			self.assertEqual("", self.getOutput(mock))
			self.assertFalse(self.getTestUser().isPaused())

	# See if we get into the paused state when we enter an invalid command during daytime hours
	def test_sets_paused_when_daytime(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		# Set us to middle of the day so we get paused
		self.setNow(dateMock, self.TUE_3PM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			self.assertEqual(self.getTestUser().state, keeper_constants.STATE_NORMAL)
			cliMsg.msg(self.testPhoneNumber, "what is blah blah")
			# ensure we got paused
			self.assertTrue(self.getTestUser().isPaused())

			# And that we got no response
			self.assertEqual("", self.getOutput(mock))

	# See if we get error message when its night
	def test_sets_paused_when_night(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		# set to night time
		self.setNow(dateMock, self.TUE_1AM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "what is blah blah", cli=True)

			# And that we got a response
			self.assertNotEqual("", self.getOutput(mock))

			# ensure we didn't get paused
			self.assertEqual(self.getTestUser().state, keeper_constants.STATE_UNKNOWN_COMMAND)

	def test_common_niceties(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		dumb_phrases = ["hi", "thanks", "no", "yes", "thanks, keeper!", "cool", "OK", u"\U0001F44D"]

		for phrase in dumb_phrases:
			with patch('smskeeper.sms_util.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, phrase)
				output = self.getOutput(mock)
				self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES, "nicety not detected: %s" % (phrase))

	def test_thanks_upsell(self, dateMock):
		# this will setup user's activated time to be TUE_8AM
		self.setupUser(True, True, dateMock=dateMock)

		# it shouldn't do the upsell an hour later
		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks")
			output = self.getOutput(mock)
			found = False
			for phrase, link in keeper_constants.SHARE_UPSELL_PHRASES:
				if phrase in output:
					found = True
			self.assertEqual(found, False)

		# a day later it should do the upsell
		self.setNow(dateMock, self.WED_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thank you")
			output = self.getOutput(mock)
			found = False
			for phrase, link in keeper_constants.SHARE_UPSELL_PHRASES:
				if phrase in output:
					found = True
			self.assertEqual(found, True)

		# make sure we don't send it immediately after
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks Keeper")
			output = self.getOutput(mock)
			found = False
			for phrase, link in keeper_constants.SHARE_UPSELL_PHRASES:
				if phrase in output:
					found = True
			self.assertEqual(found, False)

		# make sure we do send if the last share date was more than SHARE_UPSELL_FREQ prior
		self.user.last_share_upsell = self.TUE_8AM - datetime.timedelta(
			days=keeper_constants.SHARE_UPSELL_FREQUENCY_DAYS
		)
		self.user.save()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks")
			output = self.getOutput(mock)
			found = False
			for phrase, link in keeper_constants.SHARE_UPSELL_PHRASES:
				if phrase in output:
					found = True
			self.assertEqual(found, True)

	def test_thanks_upsell_before_tutorial_completed(self, dateMock):
		self.setupUser(True, False, dateMock=dateMock)

		self.setNow(dateMock, self.TUE_9AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks")
			output = self.getOutput(mock)
			found = False
			for phrase, link in keeper_constants.SHARE_UPSELL_PHRASES:
				if phrase in output:
					found = True
			self.assertEqual(found, False)

	'''
	def test_feedback_upsell(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		self.setNow(dateMock, self.TUE_9AM)
		# set activated to 3 days back and make sure feedback prompt goes out
		self.user.activated = self.TUE_8AM - datetime.timedelta(
			days=keeper_constants.FEEDBACK_MIN_ACTIVATED_TIME_IN_DAYS)
		self.user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks")
			output = self.getOutput(mock)
			self.assertIn(keeper_constants.FEEDBACK_PHRASE, output)

		# make sure feedback prompt doesn't go out again
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thanks!")
			output = self.getOutput(mock)
			self.assertNotIn(keeper_constants.FEEDBACK_PHRASE, output)

		# make sure that after 15 days, it goes out again
		user = self.getTestUser()
		user.last_feedback_prompt = self.TUE_8AM - datetime.timedelta(
			days=keeper_constants.FEEDBACK_FREQUENCY_DAYS)
		user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "thank you")
			output = self.getOutput(mock)
			self.assertIn(keeper_constants.FEEDBACK_PHRASE, output)
	'''

	def testBirthdayNicety(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		with patch('smskeeper.niceties.datetime') as dateMock:
			dateMock.date.today.return_value = datetime.date(2015, 5, 29)  # a 30 days after keeper birthday
			with patch('smskeeper.sms_util.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, "How old are you, Keeper?")
				self.assertIn("30 days", self.getOutput(mock))

	def testSendRandomEmoji(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, emoji.emojize(":green_apple:"))
			self.assertIn(self.getOutput(mock), emoji.EMOJI_UNICODE.values())
	"""
	def test_absolute_delete(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		# ensure deleting from an empty list doesn't crash
		cliMsg.msg(self.testPhoneNumber, "delete 1 #test")
		cliMsg.msg(self.testPhoneNumber, "old fashioned #cocktail")

		# First make sure that the entry is there
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertIn("old fashioned", self.getOutput(mock))

		# Next make sure we delete and the list is clear
		cliMsg.msg(self.testPhoneNumber, "delete 1 #cocktail")   # test absolute delete
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#cocktail")
			self.assertNotIn("old fashioned", self.getOutput(mock))

	def test_contextual_delete(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		for i in range(1, 2):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we don't delete when ambiguous
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertIn("Sorry, I'm not sure", self.getOutput(mock))

		# ensure deletes right item
		cliMsg.msg(self.testPhoneNumber, "#bar")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 2")
			self.assertNotIn("2. foo2", self.getOutput(mock))

		# ensure can chain deletes
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("1. foo1", self.getOutput(mock))

		# ensure deleting from empty doesn't crash
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "delete 1")
			self.assertNotIn("I deleted", self.getOutput(mock))


	def test_multi_delete(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		for i in range(1, 5):
			cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

		# ensure we can delete with or without spaces
		cliMsg.msg(self.testPhoneNumber, "delete 3, 5,2 #bar")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#bar")

			self.assertNotIn("foo2", self.getOutput(mock))
			self.assertNotIn("foo3", self.getOutput(mock))
			self.assertNotIn("foo5", self.getOutput(mock))
	"""

	def test_naturalize(self, dateMock):
		# Sunday, May 31 by 8 am
		now = datetime.datetime(2015, 05, 31, 8, 0, 0)

		# Later today
		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 9, 0, 0))
		self.assertIn("today by 9am", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 15, 0, 0))
		self.assertIn("today by 3pm", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 15, 5, 0))
		self.assertIn("today at 3:05pm", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 15, 45, 0))
		self.assertIn("today at 3:45pm", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 05, 31, 23, 45, 0))
		self.assertIn("today at 11:45pm", ret)

		# Tomorrow
		ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 1, 2, 0, 0))
		self.assertIn("tomorrow by 2am", ret)

		ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 1, 15, 0, 0))
		self.assertIn("tomorrow by 3pm", ret)

		# Day of week (this week)
		ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 2, 15, 0, 0))
		self.assertIn("Tue by 3pm", ret)

		# date of week (next week)
		ret = msg_util.naturalize(now, datetime.datetime(2015, 06, 7, 15, 0, 0))
		self.assertIn("Sun the 7th", ret)

		# a month from now
		ret = msg_util.naturalize(now, datetime.datetime(2015, 07, 7, 15, 0, 0))
		self.assertIn("July 7th", ret)

	"""
	def test_exception_error_message(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		with self.assertRaises(NameError):
			cliMsg.msg(self.testPhoneNumber, 'yippee ki yay motherfucker')

		# we have to dig into messages as ouput would never get returned from the mock
		messages = Message.objects.filter(user=self.user, incoming=False).all()
		self.assertIn(messages[0].getBody(), keeper_constants.GENERIC_ERROR_MESSAGES)
	"""

	def testSendMsgs(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		with self.assertRaises(TypeError):
			sms_util.sendMsgs(self.user, "hello", constants.SMSKEEPER_TEST_NUM)
		with self.assertRaises(TypeError):
			sms_util.sendMsg(self.user, ["hello", "this is the wrong type"], None, constants.SMSKEEPER_TEST_NUM)
	"""
	def testPhotoWithoutTag(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")
			# ensure we don't treat photos without a hashtag as a bad command
			output = self.getOutput(mock)
			self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES)
			self.assertIn(keeper_constants.PHOTO_LABEL, output)

		# make sure the entry got created
		Entry.objects.get(label=keeper_constants.PHOTO_LABEL)

	def testPhotoWithRandomText(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "this is my picture", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")
			# ensure we don't treat photos without a hashtag as a bad command
			output = self.getOutput(mock)
			self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES)
			self.assertIn(keeper_constants.PHOTO_LABEL, output)

		# make sure the entry got created
		Entry.objects.get(label=keeper_constants.PHOTO_LABEL)

	def testScreenshotWithoutTag(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.png", mediaType="image/png")
			# ensure we don't treat photos without a hashtag as a bad command
			output = self.getOutput(mock)
			self.assertNotIn(output, keeper_constants.UNKNOWN_COMMAND_PHRASES)
			self.assertIn(keeper_constants.SCREENSHOT_LABEL, output)

		# make sure the entry got created
		Entry.objects.get(label=keeper_constants.SCREENSHOT_LABEL)
	"""

	def testSetNameFirstTimeEasy(self, dateMock):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_TODO, dateMock=dateMock)
		cliMsg.msg(self.testPhoneNumber, "Foo Bar")
		self.user = User.objects.get(id=self.user.id)
		self.assertEqual(self.user.name, "Foo Bar")

	def testSetNameFirstTimePhrase(self, dateMock):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_TODO, dateMock=dateMock)
		cliMsg.msg(self.testPhoneNumber, "My name is Foo Bar")
		self.user = User.objects.get(id=self.user.id)
		self.assertEqual(self.user.name, "Foo Bar")

	def testSetNameLater(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		cliMsg.msg(self.testPhoneNumber, "My name is Foo Bar")
		self.user = User.objects.get(id=self.user.id)
		self.assertEqual(self.user.name, "Foo Bar")

	def testSetZipcodeLater(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		self.assertNotEqual(self.user.timezone, "PST")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "My zipcode is 94117")
			self.assertIn(self.getOutput(mock), keeper_constants.ACKNOWLEDGEMENT_PHRASES)
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.timezone, "US/Pacific")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "My zip code is 10012")
			self.assertIn(self.getOutput(mock), keeper_constants.ACKNOWLEDGEMENT_PHRASES)
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.timezone, "US/Eastern")

	def testStopped(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "STOP")
			self.assertIn("just type 'start'", self.getOutput(mock))
			self.assertEqual(self.getTestUser().state, keeper_constants.STATE_STOPPED)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "CANCEL")
			self.assertEqual("", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "ignore this")
			self.assertEqual("", self.getOutput(mock))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "start")
			self.assertIn("Welcome back", self.getOutput(mock))
			self.assertEqual(self.getTestUser().state, keeper_constants.STATE_NORMAL)

	def testStoppedSaveState(self, dateMock):
		self.setupUser(True, False, state=keeper_constants.STATE_NORMAL, dateMock=dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "STOP")
			self.assertIn("just type 'start'", self.getOutput(mock))
			user = self.getTestUser()
			self.assertEqual(user.state, keeper_constants.STATE_STOPPED)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "START")
			self.assertIn("welcome back", self.getOutput(mock).lower())
			user = self.getTestUser()
			self.assertEqual(user.state, keeper_constants.STATE_NORMAL)

	# Emulate a user who has a signature at the end of their messages
	def test_signatures(self, dateMock):
		self.setupUser(True, False, keeper_constants.STATE_TUTORIAL_TODO, dateMock=dateMock)
		user = self.getTestUser()
		user.signature_num_lines = None
		user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			# Activation message asks for their name
			cliMsg.msg(self.testPhoneNumber, "UnitTests\nThis Is My Sig")
			self.assertNotIn("Sig", self.getOutput(mock))
		self.assertEqual("UnitTests", self.getTestUser().name)
		self.assertEqual(1, self.getTestUser().signature_num_lines)

	# check for identical messages
	def test_identical_messages(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, 'tell me more')
			self.assertIn(self.renderTextConstant(keeper_constants.HELP_MESSAGES[0]), self.getOutput(mock))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, 'tell me more')
			self.assertEqual('', self.getOutput(mock))

	def test_reminder_clean(self, dateMock):
		s = msg_util.cleanedReminder("remind me on blah.")
		self.assertEquals(s, "blah")

		s = msg_util.cleanedReminder("remind me on blah at.")
		self.assertEquals(s, "blah")

	def test_question(self, dateMock):
		self.setupUser(True, True, dateMock=dateMock)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Are you my daddy?")
			self.assertIn(self.getOutput(mock), emoji.emojize(str(keeper_constants.UNKNOWN_COMMAND_PHRASES), use_aliases=True))

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Who is the bestests")
			self.assertIn(self.getOutput(mock), emoji.emojize(str(keeper_constants.UNKNOWN_COMMAND_PHRASES), use_aliases=True))

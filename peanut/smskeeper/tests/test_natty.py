from mock import patch

from smskeeper.models import Entry
from smskeeper import cliMsg
from common import natty_util

import test_base


class SMSKeeperNattyCase(test_base.SMSKeeperBaseCase):

	def test_unicode_natty(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, u'remind me poop\u2019s tmr')

		entry = Entry.fetchEntries(user=self.user, label="#reminders")[0]
		self.assertIn(u'Poop\u2019s', entry.text)

	# Set a user first the Eastern and make sure it comes back as a utc time for 3 pm Eastern
	# Then set the user's timezone to be Pacific and make sure natty returns a time for 3pm Pactific in UTC
	def test_natty_timezone(self):
		self.setupUser(True, True)

		cliMsg.msg(self.testPhoneNumber, "remind me poop 3pm tomorrow")

		entry = Entry.fetchEntries(user=self.user, label="#reminders")[0]

		self.assertEqual(entry.remind_timestamp.hour, 19)  # 3 pm Eastern in UTC

		self.user.timezone = "PST-2"  # This is not the default
		self.user.save()
		cliMsg.msg(self.testPhoneNumber, "remind me buy sox 1pm tomorrow")

		entries = Entry.objects.filter(label="#reminders")
		self.assertEqual(2, len(entries))

		self.assertEqual(entries[1].remind_timestamp.hour, 23)  # 1 pm Hawaii in UTC

	@patch('common.date_util.utcnow')
	def test_natty_two_times_by_words(self, dateMock):
		self.setupUser(True, True)

		self.setNow(dateMock, self.MON_8AM)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Remind me to book meeting with Andrew for tuesday morning in two hours")
			self.assertIn("by 10am", self.getOutput(mock))

	"""
	Commenting out these tests for now because we're explictly not supporting these cases right now.
	If two times are picked out of a string, we're choosing the sooner one. These tests create a situation
	where that is wrong.  If we want to change that, then can bring these tests back

	def test_natty_two_times_by_number(self):
		self.setupUser(True, True)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			inFourHours = self.getUserNow() + datetime.timedelta(hours=4)

			cliMsg.msg(self.testPhoneNumber, "#remind change archie grade to 2 in 4 hours")
			correctString = msg_util.naturalize(self.getUserNow(), inFourHours)
			self.assertIn(correctString, self.getOutput(mock))

			entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]
			self.assertIn("change archie grade to 2", entry.text)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			inFiveHours = self.getUserNow() + datetime.timedelta(hours=5)

			cliMsg.msg(self.testPhoneNumber, "#remind change bobby grade to 10 in 5 hours")
			correctString = msg_util.naturalize(self.getUserNow(), inFiveHours)
			self.assertIn(correctString, self.getOutput(mock))

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
	"""

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

		cliMsg.msg(self.testPhoneNumber, "remind me to cancel Saturday, 5/30 class this Friday at 2pm")
		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]
		self.assertEqual(entry.remind_timestamp.hour, 18)  # 2pm Eastern in UTC

		"""
		Not supporting queries with two times where one could be sooner than the other and wrong
		Look at comments above

		cliMsg.msg(self.testPhoneNumber, "#remind change archie grade to 23 at 8pm tomorrow")
		entry = Entry.fetchEntries(user=self.user, label="#reminders", hidden=False)[0]
		self.assertEqual(entry.remind_timestamp.hour, 0)  # 8pm Eastern in UTC
		"""

	def testPausedState(self):
		self.setupUser(True, True)
		user = self.getTestUser()
		user.paused = True
		user.save()

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "#reminders")
			output = self.getOutput(mock)
			self.assertIs(u'', output)


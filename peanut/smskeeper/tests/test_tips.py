import datetime
import pytz
from mock import patch

from peanut.settings import constants
from smskeeper.models import User, Message
from smskeeper import cliMsg, keeper_constants
from smskeeper import async
from smskeeper import tips

import test_base



@patch('common.date_util.utcnow')
class SMSKeeperTipsCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, activated, tutorialComplete, timezoneString, dateMock):
		self.setNow(dateMock, self.MON_11AM)
		test_base.SMSKeeperBaseCase.setupUser(self, activated, tutorialComplete)

		self.user.timezone = timezoneString  # put the user in UTC by default, makes most tests easier
		self.user.activated = self.user.activated.replace(hour=0, minute=0, second=0)  # need to make sure
		self.user.save()

	def testSendTipTimezones(self, dateMock):
		self.setupUser(True, True, "EST", dateMock)

		# make sure we don't send at the wrong time,
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.utc))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))
		# make sure we do send at the right time!
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Eastern')))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertIn("medicine", self.getOutput(mock))

	def testSendTips(self, dateMock):
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, 9, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		self.setupUser(True, True, "US/Pacific", dateMock)

		# ensure tip 1 gets sent out
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertIn("medicine", self.getOutput(mock))

		# ensure tip 2 gets sent out
		self.setNow(dateMock, datetime.datetime(2015, 6, 4, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		self.assertTipSends(self.user)

	def assertTipSends(self, user):
		with patch('smskeeper.sms_util.recordOutput') as mock:
				self.assertNotEqual(tips.selectNextFullTip(self.user), None)
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotEqual(self.getOutput(mock), None)
				self.assertNotEqual(self.getOutput(mock), "")

	def testSendTipMedia(self, dateMock):
		self.setupUser(True, True, "PST", dateMock)

		tip = tips.KeeperTip("testtip", "This is a tip", True, "http://www.getkeeper.com/favicon.png")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTipToUser(tip, self.user, constants.SMSKEEPER_TEST_NUM)
			self.assertIn("This is a tip", self.getOutput(mock))
			message = Message.objects.filter(user=self.user, incoming=False).order_by("-added")[0]
			self.assertEqual(message.getMedia()[0].url, u"http://www.getkeeper.com/favicon.png")

	def testTipThrottling(self, dateMock):
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, 9, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		self.setupUser(True, True, "PST", dateMock)

		# send a tip
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		async.sendTips(constants.SMSKEEPER_TEST_NUM)

		self.setNow(dateMock, datetime.datetime(2015, 6, 2, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.SMSKEEPER_TIPS[1].render(self.user), self.getOutput(mock))

	def testTipSameDaySignupAllMiniTipsGoFirst(self, dateMock):
		self.setupUser(True, True, "EST", dateMock)
		self.setNow(dateMock, self.MON_3PM)

		# Set product_id = 1, so daily digests are enabled.
		user = self.getTestUser()
		user.product_id = 1
		user.activated = dateMock.return_value
		user.save()

		# Now set the time to first tip delivery time later that day
		self.setNow(dateMock, self.MON_6PM)

		# Try to send a tip on first day's 6pm timeslot
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertEqual('', self.getOutput(mock))

		# Now create an entry, so morning digest has something to send
		cliMsg.msg(self.testPhoneNumber, "remind me to poop tmrw")

		# Now send out digest and its minitip
		self.setNow(dateMock, self.TUE_9AM)  # set clock ahead by 15 hours to 9am
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.processDailyDigest()
			self.assertIn('done', self.getOutput(mock))

		# Now send out the first time later that day (medicine)
		self.setNow(dateMock, self.TUE_6PM)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertIn("medicine", self.getOutput(mock))

	def testTipsSkipInactiveUsers(self, dateMock):
		# unactivated users don't get tips
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, 9, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		self.setupUser(True, False, "PST", dateMock)
		# send a tip
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

	def testSetTipFrequency(self, dateMock):
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, 9, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		self.setupUser(True, True, "PST", dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "send me tips monthly")
			# must reload the user or get a stale value for tip_frequency_days
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.tip_frequency_days, 30, "%s \n user.tip_frequency_days: %d" % (self.getOutput(mock), self.user.tip_frequency_days))

		# one day ahead
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))

		# make sure we send them soon after activation
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertIn("medicine", self.getOutput(mock))

		# make sure we don't send them in 7 days
		self.setNow(dateMock, datetime.datetime(2015, 6, 8, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

		# make sure we do send them in 31 days
		self.setNow(dateMock, datetime.datetime(2015, 7, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		self.assertTipSends(self.user)

	def testSetTipFrequencyMalformed(self, dateMock):
		self.setupUser(True, True, "PST", dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "send me tips/monthly")
			# must reload the user or get a stale value for tip_frequency_days
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.tip_frequency_days, 30, "%s \n user.tip_frequency_days: %d" % (self.getOutput(mock), self.user.tip_frequency_days))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "never send me tips")
			# must reload the user or get a stale value for tip_frequency_days
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.tip_frequency_days, 0, "%s \n user.tip_frequency_days: %d" % (self.getOutput(mock), self.user.tip_frequency_days))

	def assertTipIdNotSent(self, tipId, dateMock):
		for i, tip in enumerate(tips.SMSKEEPER_TIPS):
			self.setMockDatetimeDaysAhead(dateMock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * (i + 1), tips.SMSKEEPER_TIP_HOUR)
			tip = tips.selectNextFullTip(self.user)
			if tip:
				self.assertNotEqual(tip.id, tipId)
				tips.markTipSent(self.user, tip)

	def testTipAnalytics(self, dateMock):
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, 9, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		self.setupUser(True, True, "PST", dateMock)

		# ensure tip 1 gets sent out
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		with patch('smskeeper.analytics.logUserEvent') as analyticsMock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			events = self.getAnalyticsEvents(analyticsMock)
			self.assertNotEqual(0, len(events))
			self.assertEqual(events[0]["user"], self.user)
			self.assertEqual(events[0]["event"], "Tip Received")

	def testTipAnalyticsWithIncoming(self, dateMock):
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, 9, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		self.setupUser(True, True, "PST", dateMock)
		cliMsg.msg(self.testPhoneNumber, "add foo to bar")

		# ensure tip 1 gets sent out
		self.setNow(dateMock, datetime.datetime(2015, 6, 1, tips.SMSKEEPER_TIP_HOUR, 0, 0, tzinfo=pytz.timezone('US/Pacific')))
		with patch('smskeeper.analytics.logUserEvent') as analyticsMock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			events = self.getAnalyticsEvents(analyticsMock)
			self.assertNotEqual(0, len(events))
			self.assertEqual(events[0]["user"], self.user)
			self.assertEqual(events[0]["event"], "Tip Received")

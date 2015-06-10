import datetime
import pytz
from mock import patch

from peanut.settings import constants
from smskeeper.models import User, Message
from smskeeper import cliMsg, keeper_constants
from smskeeper import async
from smskeeper import tips

import test_base


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


class SMSKeeperTipsCase(test_base.SMSKeeperBaseCase):
	def setupUser(self, activated, tutorialComplete, timezoneString):
		test_base.SMSKeeperBaseCase.setupUser(self, activated, tutorialComplete)

		self.user.timezone = timezoneString  # put the user in UTC by default, makes most tests easier
		self.user.activated = self.user.activated.replace(hour=0, minute=0, second=0)  # need to make sure
		self.user.save()

	def testSendTipTimezones(self):
		self.setupUser(True, True, "EST")
		self.user.timezone = "EST"  # put the user in EST to test our tz conversion
		self.user.save()

		with patch('smskeeper.tips.datetime') as datetime_mock:
			# make sure we don't send at the wrong time,
			setMockDatetimeDaysAhead(datetime_mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS + 1, 0, self.user.getTimezone())
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))
		with patch('smskeeper.tips.datetime') as datetime_mock:
			# make sure we do send at the right time!
			setMockDatetimeDaysAhead(datetime_mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS + 1, tips.SMSKEEPER_TIP_HOUR, self.user.getTimezone())
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

	def testSendTips(self):
		self.setupUser(True, True, "UTC")

		with patch('smskeeper.tips.datetime') as datetime_mock:
			# ensure tip 1 gets sent out
			setMockDatetimeToSendTip(datetime_mock)
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

			# ensure tip 2 gets sent out
			setMockDatetimeDaysAhead(datetime_mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * 2, tips.SMSKEEPER_TIP_HOUR)
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[3].render(self.user), self.getOutput(mock))

	def testSendTipMedia(self):
		self.setupUser(True, True, "UTC")

		tip = tips.KeeperTip("testtip", "This is a tip", True, "http://www.getkeeper.com/favicon.png")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTipToUser(tip, self.user, constants.SMSKEEPER_TEST_NUM)
			self.assertIn("This is a tip", self.getOutput(mock))
			message = Message.objects.filter(user=self.user, incoming=False).order_by("-added")[0]
			self.assertEqual(message.getMedia()[0].url, u"http://www.getkeeper.com/favicon.png")

	def testTipThrottling(self):
		self.setupUser(True, True, "UTC")

		with patch('smskeeper.tips.datetime') as datetime_mock:
			# send a tip
			setMockDatetimeToSendTip(datetime_mock)
			async.sendTips(constants.SMSKEEPER_TEST_NUM)

			setMockDatetimeDaysAhead(datetime_mock, (keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * 2) - 1, tips.SMSKEEPER_TIP_HOUR)
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotIn(tips.SMSKEEPER_TIPS[1].render(self.user), self.getOutput(mock))

	def testTipsSkipIneligibleUsers(self):
		# unactivated users don't get tips
		self.setupUser(True, False, "UTC")
		with patch('smskeeper.tips.datetime') as datetime_mock:
			# send a tip
			setMockDatetimeToSendTip(datetime_mock)
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

	def testSetTipFrequency(self):
		self.setupUser(True, True, "UTC")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "send me tips monthly")
			# must reload the user or get a stale value for tip_frequency_days
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.tip_frequency_days, 30, "%s \n user.tip_frequency_days: %d" % (self.getOutput(mock), self.user.tip_frequency_days))

		with patch('smskeeper.tips.datetime') as datetime_mock:

			setMockDatetimeDaysAhead(datetime_mock, 1, tips.SMSKEEPER_TIP_HOUR)

			# make sure we send them soon after activation
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

			setMockDatetimeDaysAhead(datetime_mock, 7, tips.SMSKEEPER_TIP_HOUR)

			# make sure we don't send them in 7 days
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

			# make sure we do send them in 31 days
			setMockDatetimeDaysAhead(datetime_mock, 31, tips.SMSKEEPER_TIP_HOUR)
			with patch('smskeeper.sms_util.recordOutput') as mock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertIn(tips.SMSKEEPER_TIPS[3].render(self.user), self.getOutput(mock))

	def testSetTipFrequencyMalformed(self):
		self.setupUser(True, True, "UTC")
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

	def testReminderTipRelevance(self):
		self.setupUser(True, True, "UTC")
		with patch('smskeeper.sms_util.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "#reminder test tomorrow")  # set a reminder
			self.assertTipIdNotSent(tips.REMINDER_TIP_ID)

	def testPhotoTipRelevance(self):
		self.setupUser(True, True, "UTC")

		with patch('smskeeper.sms_util.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")  # add a photo
			self.assertTipIdNotSent(tips.PHOTOS_TIP_ID)

		with patch('smskeeper.sms_util.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "#reminder test tomorrow")  # set a reminder
			self.assertTipIdNotSent(tips.REMINDER_TIP_ID)

	def testShareTipRelevance(self):
		self.setupUser(True, True, "UTC")
		with patch('smskeeper.sms_util.recordOutput'):
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

	def testTipAnalytics(self):
		self.setupUser(True, True, "UTC")

		with patch('smskeeper.tips.datetime') as datetime_mock:
			# ensure tip 1 gets sent out
			setMockDatetimeToSendTip(datetime_mock)
			with patch('smskeeper.analytics.logUserEvent') as analyticsMock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				events = self.getAnalyticsEvents(analyticsMock)
				self.assertEqual(events[0]["user"], self.user)
				self.assertEqual(events[0]["event"], "Tip Received")

	def testTipAnalyticsWithIncoming(self):
		self.setupUser(True, True, "UTC")
		cliMsg.msg(self.testPhoneNumber, "add foo to bar")

		with patch('smskeeper.tips.datetime') as datetime_mock:
			# ensure tip 1 gets sent out
			setMockDatetimeToSendTip(datetime_mock)
			with patch('smskeeper.analytics.logUserEvent') as analyticsMock:
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				events = self.getAnalyticsEvents(analyticsMock)
				self.assertEqual(events[0]["user"], self.user)
				self.assertEqual(events[0]["event"], "Tip Received")

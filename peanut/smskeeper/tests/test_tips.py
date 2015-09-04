import datetime
import pytz
from mock import patch

from peanut.settings import constants
from smskeeper.models import User, Message
from smskeeper import cliMsg, keeper_constants
from smskeeper import async
from smskeeper import tips

from common import date_util

import test_base



@patch('common.date_util.utcnow')
class SMSKeeperTipsCase(test_base.SMSKeeperBaseCase):

	def setMockDatetimeDaysAhead(self, mock, days, customHour=None, customTimeZone=None):
		dt = datetime.datetime.now(pytz.utc) + datetime.timedelta(days)
		if customHour is not None:
			dt = dt.replace(hour=customHour)
		if customTimeZone is not None:
			dt = dt.astimezone(customTimeZone)

		self.setNow(mock, dt)

	def setMockDatetimeToSendTip(self, mock):
		self.setMockDatetimeDaysAhead(mock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS, tips.SMSKEEPER_TIP_HOUR)

	def setupUser(self, activated, tutorialComplete, timezoneString, dateMock):
		self.setNow(dateMock, self.MON_11AM)
		test_base.SMSKeeperBaseCase.setupUser(self, activated, tutorialComplete)

		self.user.timezone = timezoneString  # put the user in UTC by default, makes most tests easier
		self.user.activated = self.user.activated.replace(hour=0, minute=0, second=0)  # need to make sure
		self.user.save()

	def testSendTipTimezones(self, dateMock):
		self.setupUser(True, True, "EST", dateMock)

		# make sure we don't send at the wrong time,
		self.setMockDatetimeDaysAhead(dateMock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS + 1, 0, self.user.getTimezone())
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))
		# make sure we do send at the right time!
		customHour = tips.SMSKEEPER_TIP_HOUR + 4  # Need to add 4 since we're now in EST to make the mock work
		self.setMockDatetimeDaysAhead(dateMock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS + 1, customHour, self.user.getTimezone())
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertIn("medicine", self.getOutput(mock))

	def testSendTips(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)

		# ensure tip 1 gets sent out
		self.setMockDatetimeToSendTip(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertIn("medicine", self.getOutput(mock))

		# ensure tip 2 gets sent out
		self.setMockDatetimeDaysAhead(dateMock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * 2, tips.SMSKEEPER_TIP_HOUR)
		self.assertTipSends(self.user)

	def assertTipSends(self, user):
		with patch('smskeeper.sms_util.recordOutput') as mock:
				self.assertNotEqual(tips.selectNextFullTip(self.user), None)
				async.sendTips(constants.SMSKEEPER_TEST_NUM)
				self.assertNotEqual(self.getOutput(mock), None)
				self.assertNotEqual(self.getOutput(mock), "")

	def testSendTipMedia(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)

		tip = tips.KeeperTip("testtip", "This is a tip", True, "http://www.getkeeper.com/favicon.png")
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTipToUser(tip, self.user, constants.SMSKEEPER_TEST_NUM)
			self.assertIn("This is a tip", self.getOutput(mock))
			message = Message.objects.filter(user=self.user, incoming=False).order_by("-added")[0]
			self.assertEqual(message.getMedia()[0].url, u"http://www.getkeeper.com/favicon.png")

	def testTipThrottling(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)

		# send a tip
		self.setMockDatetimeToSendTip(dateMock)
		async.sendTips(constants.SMSKEEPER_TEST_NUM)

		self.setMockDatetimeDaysAhead(dateMock, (keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * 2) - 1, tips.SMSKEEPER_TIP_HOUR)
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



	def testTipsSkipIneligibleUsers(self, dateMock):
		# unactivated users don't get tips
		self.setupUser(True, False, "UTC", dateMock)
		self.setNow(dateMock, self.MON_9AM)
		# send a tip
		self.setMockDatetimeToSendTip(dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

	def testSetTipFrequency(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "send me tips monthly")
			# must reload the user or get a stale value for tip_frequency_days
			self.user = User.objects.get(id=self.user.id)
			self.assertEqual(self.user.tip_frequency_days, 30, "%s \n user.tip_frequency_days: %d" % (self.getOutput(mock), self.user.tip_frequency_days))

		self.setMockDatetimeDaysAhead(dateMock, 1, tips.SMSKEEPER_TIP_HOUR)

		# make sure we send them soon after activation
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertIn("medicine", self.getOutput(mock))

		self.setMockDatetimeDaysAhead(dateMock, 7, tips.SMSKEEPER_TIP_HOUR)

		# make sure we don't send them in 7 days
		with patch('smskeeper.sms_util.recordOutput') as mock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			self.assertNotIn(tips.SMSKEEPER_TIPS[0].render(self.user), self.getOutput(mock))

		# make sure we do send them in 31 days
		self.setMockDatetimeDaysAhead(dateMock, 31, tips.SMSKEEPER_TIP_HOUR)
		self.assertTipSends(self.user)

	def testSetTipFrequencyMalformed(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)
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

	def testReminderTipRelevance(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)
		with patch('smskeeper.sms_util.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "#reminder test tomorrow")  # set a reminder
			self.assertTipIdNotSent(tips.REMINDER_TIP_ID, dateMock)

	def testPhotoTipRelevance(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)

		with patch('smskeeper.sms_util.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "", mediaURL="http://getkeeper.com/favicon.jpeg", mediaType="image/jpeg")  # add a photo
			self.assertTipIdNotSent(tips.PHOTOS_TIP_ID, dateMock)

		with patch('smskeeper.sms_util.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "#reminder test tomorrow")  # set a reminder
			self.assertTipIdNotSent(tips.REMINDER_TIP_ID, dateMock)

	def testShareTipRelevance(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)
		with patch('smskeeper.sms_util.recordOutput'):
			cliMsg.msg(self.testPhoneNumber, "foo #bar @baz")  # share something
			cliMsg.msg(self.testPhoneNumber, "9175551234")  # share something
			self.assertTipIdNotSent(tips.SHARING_TIP_ID, dateMock)

	def assertTipIdNotSent(self, tipId, dateMock):
		for i, tip in enumerate(tips.SMSKEEPER_TIPS):
			self.setMockDatetimeDaysAhead(dateMock, keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS * (i + 1), tips.SMSKEEPER_TIP_HOUR)
			tip = tips.selectNextFullTip(self.user)
			if tip:
				self.assertNotEqual(tip.id, tipId)
				tips.markTipSent(self.user, tip)

	def testTipAnalytics(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)

		# ensure tip 1 gets sent out
		self.setMockDatetimeToSendTip(dateMock)
		with patch('smskeeper.analytics.logUserEvent') as analyticsMock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			events = self.getAnalyticsEvents(analyticsMock)
			self.assertNotEqual(0, len(events))
			self.assertEqual(events[0]["user"], self.user)
			self.assertEqual(events[0]["event"], "Tip Received")

	def testTipAnalyticsWithIncoming(self, dateMock):
		self.setupUser(True, True, "UTC", dateMock)
		cliMsg.msg(self.testPhoneNumber, "add foo to bar")

		# ensure tip 1 gets sent out
		self.setMockDatetimeToSendTip(dateMock)
		with patch('smskeeper.analytics.logUserEvent') as analyticsMock:
			async.sendTips(constants.SMSKEEPER_TEST_NUM)
			events = self.getAnalyticsEvents(analyticsMock)
			self.assertNotEqual(0, len(events))
			self.assertEqual(events[0]["user"], self.user)
			self.assertEqual(events[0]["event"], "Tip Received")

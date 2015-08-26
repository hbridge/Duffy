# -*- coding: utf-8 -*-

from mock import patch
import logging

from smskeeper import cliMsg

import test_base

logger = logging.getLogger()
logger.level = logging.DEBUG


@patch('common.date_util.utcnow')
class SMSKeeperTestCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, dateMock):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		super(SMSKeeperTestCase, self).setupUser(True, True, productId=1)

	def test_remove_time_of_day(self, dateMock):
		self.setupUser(dateMock)
		timesOfDay = ["morning", "afternoon", "evening", "night"]
		for timeOfDay in timesOfDay:
			cliMsg.msg(self.testPhoneNumber, "Remind me to poop tomorrow %s at 12" % timeOfDay)

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "todo")
			for timeOfDay in timesOfDay:
				self.assertNotIn(timeOfDay, self.getOutput(mock).lower())

	def test_remove_endings(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Go to the dentist tomorrow, remind me")
		entry = self.getTestUser().getLastEntries()[0]
		self.assertNotIn("remind me", entry.text)
		self.assertNotIn(",", entry.text)

	def test_remove_too_many_spaces(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Remind me to mess with    the     text")
		entry = self.getTestUser().getLastEntries()[0]
		self.assertEqual("mess with the text", entry.text.lower())

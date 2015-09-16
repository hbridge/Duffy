# -*- coding: utf-8 -*-


from mock import patch
import logging

from smskeeper import cliMsg
from smskeeper import keeper_constants

import test_base

logger = logging.getLogger()
logger.level = logging.DEBUG


@patch('common.date_util.utcnow')
class SMSKeeperTestCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, dateMock):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		super(SMSKeeperTestCase, self).setupUser(True, True, productId=1)

	def test_hi(self, dateMock):
		self.setupUser(dateMock)
		cliMsg.msg(self.testPhoneNumber, "Hi Keeper!")
		self.assertEqual(self.user.lastIncomingMessageAutoclass(), keeper_constants.CLASS_NICETY)

	def test_birthday(self, dateMock):
		self.setupUser(dateMock)
		for message in ["Today is my birthday", "It's my birthday!", "It's my bday!"]:
			with patch('smskeeper.sms_util.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, message)
				self.assertIn("happy birthday", self.getOutput(mock).lower(), "Nicety phrase failed: %s" % message)

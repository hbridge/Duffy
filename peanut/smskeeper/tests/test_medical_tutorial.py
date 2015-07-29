import datetime
import pytz

from mock import patch

from smskeeper import cliMsg, keeper_constants
from smskeeper.models import Entry

import test_base


@patch('common.date_util.utcnow')
class SMSKeeperMedicalTutorialCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, dateMock, productId=keeper_constants.MEDICAL_PRODUCT_ID):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		super(SMSKeeperMedicalTutorialCase, self).setupUser(True, False, keeper_constants.STATE_TUTORIAL_MEDICAL, productId=productId)

	def test_tutorial_remind_normal(self, dateMock):
		self.setupUser(dateMock)

		# Activation message asks for their name
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "UnitTests")
			self.assertIn("nice to meet you UnitTests!", self.getOutput(mock))
			self.assertEquals(self.getTestUser().name, "UnitTests")

		# Activation message asks for their zip
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "10012")
			self.assertIn("Thanks! Let's create a reminder", self.getOutput(mock))
			self.assertEqual(self.getTestUser().postal_code, "10012")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to take my pills everyday at 2pm")
			self.assertIn("later today by 2pm", self.getOutput(mock))

	def test_tutorial_every_wednesday(self, dateMock):
		self.setupUser(dateMock)

		cliMsg.msg(self.testPhoneNumber, "UnitTests")
		cliMsg.msg(self.testPhoneNumber, "10012")

		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "remind me to exercise every wednesday")
			self.assertIn("tomorrow", self.getOutput(mock))

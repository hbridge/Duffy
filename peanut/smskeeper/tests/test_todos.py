from mock import patch

from smskeeper import cliMsg, keeper_constants
from smskeeper.models import Entry

import test_base


class SMSKeeperReminderCase(test_base.SMSKeeperBaseCase):

	def setupUser(self):
		super(SMSKeeperReminderCase, self).setupUser(True, True, productId=1)

	def test_todo_basic(self):
		self.setupUser()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "I need to pick up my sox tomorrow")
			self.assertIn("tomorrow around 9am", self.getOutput(mock))

		entry = Entry.objects.get(label="#reminders")
		self.assertEquals("I need to pick up my sox", entry.text)

	def test_question(self):
		self.setupUser()
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Are you my daddy?")
			self.assertIn(self.getOutput(mock), keeper_constants.UNKNOWN_COMMAND_PHRASES)

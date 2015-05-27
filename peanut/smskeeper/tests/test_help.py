from mock import patch

from smskeeper import msg_util, cliMsg, keeper_constants
from smskeeper.models import Entry

import test_base

class SMSKeeperHelpCase(test_base.SMSKeeperBaseCase):
	def test_help(self):
		self.setupUser(True, True)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "huh?")
			self.assertIn(keeper_constants.HELP_MESSAGES[0], self.getOutput(mock))
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "more about lists")
			self.assertIn(
				keeper_constants.HELP_SUBJECTS[keeper_constants.LISTS_HELP_SUBJECT][keeper_constants.GENERAL_HELP_KEY][0],
				self.getOutput(mock)
			)
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "more examples please")
			self.assertIn(
				keeper_constants.HELP_SUBJECTS[keeper_constants.LISTS_HELP_SUBJECT][keeper_constants.EXAMPLES_HELP_KEY][0],
				self.getOutput(mock)
			)

		# make sure we can ask for reminders without going back
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Reminders")
			self.assertIn(
				keeper_constants.HELP_SUBJECTS[keeper_constants.REMINDERS_HELP_SUBJECT][keeper_constants.GENERAL_HELP_KEY][0],
				self.getOutput(mock)
			)

		# make sure we can get out of the tutorial state by adding something
		with patch('smskeeper.async.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "add X to Y")
			Entry.objects.get(creator=self.user)

def test_help_aliases(self):
		self.setupUser(True, True)
		aliases = ["help", "tell me more", "huh?"]
		for alias in aliases:
			with patch('smskeeper.async.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, alias)
				self.assertIn(keeper_constants.HELP_MESSAGES[0], self.getOutput(mock))

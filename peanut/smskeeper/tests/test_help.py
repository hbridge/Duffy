from mock import patch

from smskeeper import cliMsg, keeper_constants
from smskeeper.models import Entry

import test_base


class SMSKeeperHelpCase(test_base.SMSKeeperBaseCase):


	def test_help(self):
		self.setupUser(True, True)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "huh?")
			self.assertIn(keeper_constants.HELP_MESSAGES[0], self.getOutput(mock))

	# commenting all the original test cases out, since Help is now stateless and simpler
	'''
	def test_help(self):
		self.setupUser(True, True)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "huh?")
			self.assertIn(keeper_constants.HELP_MESSAGES[0], self.getOutput(mock))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "more about lists")
			self.assertIn(
				keeper_constants.HELP_SUBJECTS[keeper_constants.LISTS_HELP_SUBJECT][keeper_constants.GENERAL_HELP_KEY][0],
				self.getOutput(mock)
			)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "more examples please")
			self.assertIn(
				keeper_constants.HELP_SUBJECTS[keeper_constants.LISTS_HELP_SUBJECT][keeper_constants.EXAMPLES_HELP_KEY][0],
				self.getOutput(mock)
			)

		# make sure we can ask for reminders without going back
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "Reminders")
			self.assertIn(
				keeper_constants.HELP_SUBJECTS[keeper_constants.REMINDERS_HELP_SUBJECT][keeper_constants.GENERAL_HELP_KEY][0],
				self.getOutput(mock)
			)

		# make sure we can get out of the tutorial state by adding something
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "add X to Y")
			Entry.objects.get(creator=self.user)
	
	def test_help_add_list_from_help(self):
		self.setupUser(True, True)
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "huh?")
			self.assertIn(keeper_constants.HELP_MESSAGES[0], self.getOutput(mock))
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "add blah to my todo list")
			self.assertIn("Just type 'todo' to get these back", self.getOutput(mock))

	def test_help_aliases(self):
		self.setupUser(True, True)
		aliases = ["help", "tell me more", "huh?"]
		for alias in aliases:
			with patch('smskeeper.sms_util.recordOutput') as mock:
				cliMsg.msg(self.testPhoneNumber, alias)
				self.assertIn(keeper_constants.HELP_MESSAGES[0], self.getOutput(mock))

	def test_get_lists_after_help(self):
		self.setupUser(True, True)
		cliMsg.msg(self.testPhoneNumber, "add foo to barbaz")
		cliMsg.msg(self.testPhoneNumber, "huh?")
		cliMsg.msg(self.testPhoneNumber, "lists")
		cliMsg.msg(self.testPhoneNumber, "reminders")  # we do reminders so we don't hit the repeat message detection for lists
		with patch('smskeeper.sms_util.recordOutput') as mock:
			cliMsg.msg(self.testPhoneNumber, "lists")
			self.assertIn("barbaz", self.getOutput(mock))
	'''
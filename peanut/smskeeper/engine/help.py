import re

from smskeeper import keeper_constants, sms_util
from smskeeper import analytics
from .action import Action


class HelpAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_HELP

	help_re = re.compile(r'help$|how do .* work|what .*(can|do) you do|tell me more', re.I)

	def getScore(self, chunk, user):
		score = 0.0

		if self.help_re.match(chunk.normalizedText()) is not None:
			score = 1.0

		return score

	def execute(self, chunk, user):
		sms_util.sendMsgs(user, keeper_constants.HELP_MESSAGES)
		analytics.logUserEvent(
			user,
			"Requested Help",
			{
				"Message": chunk.originalText.lower()
			}
		)
		return True

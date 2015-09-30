from smskeeper import keeper_constants, sms_util, keeper_strings
from smskeeper import analytics
from .action import Action


class HelpAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_HELP

	def getScore(self, chunk, user, features):
		score = 0.0

		if features.startsWithHelpPhrase:
			score = 1.0

		return score

	def execute(self, chunk, user, features):
		sms_util.sendMsgs(user, keeper_strings.HELP_MESSAGES)
		analytics.logUserEvent(
			user,
			"Requested Help",
			{
				"Message": chunk.originalText.lower()
			}
		)
		return True

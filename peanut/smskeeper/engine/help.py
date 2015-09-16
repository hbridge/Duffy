from smskeeper import keeper_constants, sms_util, keeper_strings
from smskeeper import analytics
from .action import Action

from smskeeper.chunk_features import ChunkFeatures


class HelpAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_HELP

	def getScore(self, chunk, user):
		score = 0.0

		features = ChunkFeatures(chunk, user)

		if features.startsWithHelpPhrase():
			score = 1.0

		return score

	def execute(self, chunk, user):
		sms_util.sendMsgs(user, keeper_strings.HELP_MESSAGES)
		analytics.logUserEvent(
			user,
			"Requested Help",
			{
				"Message": chunk.originalText.lower()
			}
		)
		return True

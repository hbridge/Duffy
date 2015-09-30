from smskeeper import actions
from smskeeper import keeper_constants
from .action import Action


class FrustrationAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FRUSTRATION

	def getScore(self, chunk, user, features):
		score = 0.0

		if features.beginsWithNo:
			score = 0.6

		return score

	def execute(self, chunk, user, features):
		actions.unknown(user, chunk.originalText, user.getKeeperNumber(), keeper_constants.UNKNOWN_TYPE_FRUSTRATION, doPause=True)
		return True

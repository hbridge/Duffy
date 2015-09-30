from smskeeper import actions
from smskeeper import keeper_constants
from .action import Action


class QuestionAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_QUESTION

	def getScore(self, chunk, user, features):
		score = 0.0

		if features.isQuestion:
			score = .6

		if features.inTutorial:
			score = 0.0

		return score

	def execute(self, chunk, user, features):
		actions.unknown(user, chunk.originalText, user.getKeeperNumber(), keeper_constants.UNKNOWN_TYPE_QUESTION, doAlert=True)
		return True

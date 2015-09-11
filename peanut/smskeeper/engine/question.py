from smskeeper import actions, msg_util
from smskeeper import keeper_constants
from .action import Action


class QuestionAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_QUESTION

	def getScore(self, chunk, user):
		score = 0.0

		firstWord = msg_util.getFirstWord(chunk.originalText)
		question_re = ("?" in chunk.originalText) or firstWord in ["who", "what", "where", "when", "why", "how", "what's", "whats", "is", "are"]

		if question_re:
			score = .6

		if QuestionAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		if not user.isTutorialComplete():
			score = 0.0

		return score

	def execute(self, chunk, user):
		actions.unknown(user, chunk.originalText, user.getKeeperNumber(), keeper_constants.UNKNOWN_TYPE_QUESTION, doAlert=True)
		return True

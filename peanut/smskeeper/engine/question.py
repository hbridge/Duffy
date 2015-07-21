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
			score = .5

		if QuestionAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		# TODO(Derek): Remove this once reminder stuff has been moved over to new processing engine
		if msg_util.isRemindCommand(chunk.originalText):
			score = 0.0

		if msg_util.isDigestCommand(chunk.originalText):
			score = 0.0

		if not user.isTutorialComplete():
			score = 0.0

		if msg_util.isSetTipFrequencyCommand(chunk.originalText):
			score = 0.0

		if msg_util.nameInSetName(chunk.originalText):
			score = 0.0

		if msg_util.isSetZipcodeCommand(chunk.originalText):
			score = 0.0

		return score

	def execute(self, chunk, user):
		actions.unknown(user, chunk.originalText, user.getKeeperNumber())

from smskeeper import actions
from smskeeper import keeper_constants
from smskeeper import chunk_features
from .action import Action


class QuestionAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_QUESTION

	def getScore(self, chunk, user):
		score = 0.0
		features = chunk_features.ChunkFeatures(chunk, user)

		if features.isQuestion():
			score = .6

		if QuestionAction.HasHistoricalMatchForChunk(chunk):
			score = .5

		if features.inTutorial():
			score = 0.0

		return score

	def execute(self, chunk, user):
		actions.unknown(user, chunk.originalText, user.getKeeperNumber(), keeper_constants.UNKNOWN_TYPE_QUESTION, doAlert=True)
		return True

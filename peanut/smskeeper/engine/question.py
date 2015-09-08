from smskeeper import actions
from smskeeper import keeper_constants
from .action import Action
from smskeeper.chunk_features import ChunkFeatures


class QuestionAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_QUESTION

	def getScore(self, chunk, user):
		score = 0.0
		features = ChunkFeatures(chunk, user)

		if features.isQuestion():
			score = .6
		if features.isBroadQuestion():
			score = 0.8

		if QuestionAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		if not user.isTutorialComplete():
			score = 0.0

		return score

	def execute(self, chunk, user):
		actions.unknown(user, chunk.originalText, user.getKeeperNumber())
		return True

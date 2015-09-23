from smskeeper import actions, chunk_features
from smskeeper import keeper_constants
from .action import Action


class FrustrationAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FRUSTRATION

	def getScore(self, chunk, user):
		score = 0.0

		features = chunk_features.ChunkFeatures(chunk, user)

		if features.beginsWithNo():
			score = 0.6

		if FrustrationAction.HasHistoricalMatchForChunk(chunk):
			score = .5

		return score

	def execute(self, chunk, user):
		actions.unknown(user, chunk.originalText, user.getKeeperNumber(), keeper_constants.UNKNOWN_TYPE_FRUSTRATION, doPause=True)
		return True

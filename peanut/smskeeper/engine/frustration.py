from smskeeper import actions, msg_util
from smskeeper import keeper_constants
from .action import Action


class FrustrationAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FRUSTRATION

	def getScore(self, chunk, user):
		score = 0.0

		if msg_util.startsWithNo(chunk.normalizedText()):
			score = 0.4

		if FrustrationAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		actions.unknown(user, chunk.originalText, user.getKeeperNumber())
		return True

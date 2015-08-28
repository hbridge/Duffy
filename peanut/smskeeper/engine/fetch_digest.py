import logging

from smskeeper import async
from smskeeper import keeper_constants
from .action import Action
from smskeeper.chunk_features import ChunkFeatures

logger = logging.getLogger(__name__)


class FetchDigestAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FETCH_DIGEST

	def getScore(self, chunk, user):
		score = 0.0
		chunkFeatures = ChunkFeatures(chunk, user)

		scoreVector = []
		scoreVector.append(0.2 if chunkFeatures.hasFetchDigestWords() else 0)
		scoreVector.append(0.6 if chunkFeatures.isFetchDigestPhrase() else 0)
		scoreVector.append(0.2 if chunkFeatures.isQuestion() else 0)
		scoreVector.append(-0.5 if chunkFeatures.isBroadQuestion() else 0)
		scoreVector.append(0.1 if chunkFeatures.containsToday() else 0)
		scoreVector.append(-0.5 if chunkFeatures.hasTimeOfDay() else 0)
		scoreVector.append(-0.2 if chunkFeatures.couldBeDone() else 0)

		logger.debug("User %d: fetch digest score vector: %s", user.id, scoreVector)
		score = sum(scoreVector)

		if FetchDigestAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		if "today" in chunk.normalizedText():
			async.sendDigestForUserId(user.id, user.getKeeperNumber())
		else:
			async.sendAllRemindersForUserId(user.id, user.getKeeperNumber())
		return True

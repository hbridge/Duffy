import logging

from smskeeper import async
from smskeeper import keeper_constants
from .action import Action

logger = logging.getLogger(__name__)


class FetchDigestAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FETCH_DIGEST

	def getScore(self, chunk, user, features):
		score = 0.0

		scoreVector = []
		scoreVector.append(0.2 * features.numFetchDigestWords)
		scoreVector.append(0.1 if features.containsFirstPersonWord else 0)
		scoreVector.append(0.6 if features.isFetchDigestPhrase else 0)
		scoreVector.append(0.4 if features.isQuestion else 0)
		scoreVector.append(-0.5 if features.isBroadQuestion else 0)
		scoreVector.append(0.1 if features.containsToday else 0)
		scoreVector.append(-0.5 if features.hasTimeOfDay else 0)
		scoreVector.append(-0.2 if features.couldBeDone else 0)
		scoreVector.append(-0.2 if features.looksLikeList else 0)

		logger.info("User %d: fetch digest score vector: %s", user.id, scoreVector)
		score = sum(scoreVector)

		if FetchDigestAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user, features):
		if "today" in chunk.normalizedText():
			async.sendDigestForUserId(user.id, user.getKeeperNumber())
		else:
			async.sendAllRemindersForUserId(user.id, user.getKeeperNumber())
		return True

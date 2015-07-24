import logging
import re

from smskeeper import async
from smskeeper import keeper_constants
from .action import Action

logger = logging.getLogger(__name__)


class FetchDigestAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FETCH_DIGEST

	digestRegex = re.compile(r"(what('s| is) on my )?(todo(s)?|task(s)?)( list)?$|what do i have to do today|tasks for today", re.I)

	def getScore(self, chunk, user):
		score = 0.0

		if self.digestRegex.search(chunk.normalizedText()) is not None:
			score = 0.8

		if FetchDigestAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		if "today" in chunk.normalizedText():
			async.sendDigestForUserId(user.id, user.getKeeperNumber())
		else:
			async.sendAllRemindersForUserId(user.id, user.getKeeperNumber())
		return True

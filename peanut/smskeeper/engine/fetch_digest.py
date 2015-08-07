import logging

from smskeeper import async, msg_util
from smskeeper import keeper_constants
from .action import Action

logger = logging.getLogger(__name__)


class FetchDigestAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FETCH_DIGEST

	digestRegex = r"(what('s| is) on my )?(todo(s)?|task(s)?)( list)?$|what do i have to do today|tasks for today"
	beginsWithRegex = r"^(tasks)\b"

	def getScore(self, chunk, user):
		score = 0.0

		couldBeDone = msg_util.done_re.search(chunk.normalizedText()) is not None

		if chunk.matches(self.digestRegex):
			score = 0.8

		if chunk.matches(self.beginsWithRegex):
			score = 0.9

		if couldBeDone:
			score -= 0.1

		if FetchDigestAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		if "today" in chunk.normalizedText():
			async.sendDigestForUserId(user.id, user.getKeeperNumber())
		else:
			async.sendAllRemindersForUserId(user.id, user.getKeeperNumber())
		return True

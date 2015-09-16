import logging

from smskeeper import msg_util, sms_util
from smskeeper import keeper_constants
from .action import Action
from smskeeper import analytics
from smskeeper.chunk_features import ChunkFeatures

logger = logging.getLogger(__name__)


class CompleteTodoMostRecentAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_COMPLETE_TODO_MOST_RECENT

	def getScore(self, chunk, user):
		score = 0.0

		features = ChunkFeatures(chunk, user)

		if features.hasDoneWord() and features.numInterestingWords() == 0 and features.numMatchingEntriesBroad() == 0:
			if features.wasRecentlySentMsgOfClassReminder() or features.wasRecentlySentMsgOfClassDigest():
				score = 0.9
			else:
				score = 0.7

		if features.hasDoneWord() and features.hasNicety():
			score = 0.6

		if features.hasTimingInfo():
			score = 0.0

		if CompleteTodoMostRecentAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		entries = user.getLastEntries()

		for entry in entries:
			if entry.remind_recur == keeper_constants.RECUR_DEFAULT:
				entry.hidden = True
				logger.info("User %s: Marking off entry %s as hidden" % (user.id, entry.id))
				entry.save()
			else:
				logger.debug("User %s: Didn't mark off entry %s as hidden since its not recur_default" % (user.id, entry.id))

		features = ChunkFeatures(chunk, user)
		msgBack = msg_util.renderDoneResponse(entries, features.containsDeleteWord())

		if msgBack:
			sms_util.sendMsg(user, msgBack)
			user.done_count += 1
			user.save()

		analytics.logUserEvent(
			user,
			"Completed Todo",
			{
				"Done Type": "Contextual",
				"Todo Count": len(entries),
				"Done Count": user.done_count
			}
		)

		return True

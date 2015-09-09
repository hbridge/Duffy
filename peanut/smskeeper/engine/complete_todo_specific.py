import logging

from smskeeper import entry_util, sms_util, actions, chunk_features, msg_util
from smskeeper import keeper_constants
from smskeeper import analytics
from .action import Action
from smskeeper.chunk_features import ChunkFeatures

logger = logging.getLogger(__name__)


class CompleteTodoSpecificAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_COMPLETE_TODO_SPECIFIC

	def getScore(self, chunk, user):
		score = 0.0

		features = chunk_features.ChunkFeatures(chunk, user)

		numInterestingWords = features.numInterestingWords()
		hasDoneWord = features.hasDoneWord()
		beginsWithDoneWord = features.beginsWithDoneWord()
		numBestEntries = features.numMatchingEntriesStrict()
		hasTimingInfo = features.hasTimingInfo()

		if numBestEntries > 0 and numInterestingWords >= 2:
			score = 0.3

		if hasDoneWord and numInterestingWords >= 2:
			score = 0.5

		if hasDoneWord and numBestEntries > 0:
			score = 0.9

		if hasTimingInfo:
			score -= .15

		if CompleteTodoSpecificAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		if score < 0.9 and beginsWithDoneWord:
			score += 0.1

		return score

	def execute(self, chunk, user):
		cleanedCommand = msg_util.getInterestingWords(chunk.originalText, removeDones=True)

		entries = entry_util.fuzzyMatchEntries(user, ' '.join(cleanedCommand))

		for entry in entries:
			entry.hidden = True
			logger.info("User %s: Marking off entry %s as hidden" % (user.id, entry.id))
			entry.save()

		features = ChunkFeatures(chunk, user)
		msgBack = msg_util.renderDoneResponse(entries, features.containsDeleteWord())

		if msgBack:
			sms_util.sendMsg(user, msgBack)
			user.done_count += 1
			user.save()
		else:
			logger.info("User %s: I thought '%s' was a completetodo specific command but couldn't find an entry to match on, pausing" % (user.id, chunk.originalText))
			daytime = actions.unknown(user, chunk.originalText, user.getKeeperNumber(), sendMsg=False, doAlert=True)

			if not daytime:
				msgBack = "Sorry, I'm not sure what entry you mean. Could you rephrase?"
				sms_util.sendMsg(user, msgBack, None, user.getKeeperNumber())

		analytics.logUserEvent(
			user,
			"Completed Todo",
			{
				"Done Type": "Specific",
				"Todo Count": len(entries),
				"Done Count": user.done_count
			}
		)

		return True

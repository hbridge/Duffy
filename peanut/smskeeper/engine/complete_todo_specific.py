import logging

from smskeeper import entry_util, sms_util, actions, chunk_features
from smskeeper import keeper_constants
from smskeeper import analytics
from .action import Action

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
			score -= .2

		if CompleteTodoSpecificAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		if score < 0.9 and beginsWithDoneWord:
			score += 0.1

		return score

	def execute(self, chunk, user):
		entries = entry_util.fuzzyMatchEntries(user, chunk.originalText)

		for entry in entries:
			entry.hidden = True
			logger.info("User %s: Marking off entry %s as hidden" % (user.id, entry.id))
			entry.save()

		msgBack = None
		if len(entries) == 1:
			msgBack = "Nice! Checked that off :white_check_mark:"
		elif len(entries) > 1:
			msgBack = "Nice! Checked those off :white_check_mark:"

		if msgBack:
			sms_util.sendMsg(user, msgBack)
		else:
			logger.info("User %s: I thought '%s' was a completetodo specific command but couldn't find an entry to match on, pausing" % (user.id, chunk.originalText))
			paused = actions.unknown(user, chunk.originalText, user.getKeeperNumber(), sendMsg=False)
			if not paused:
				msgBack = "Sorry, I'm not sure what entry you mean."
				sms_util.sendMsg(user, msgBack, None, user.getKeeperNumber())

		analytics.logUserEvent(
			user,
			"Completed Todo",
			{
				"Done Type": "Specific",
				"Todo Count": len(entries)
			}
		)

		return True

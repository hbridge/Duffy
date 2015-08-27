import logging

from smskeeper import msg_util, sms_util, entry_util
from smskeeper import keeper_constants
from .action import Action
from smskeeper import niceties
from smskeeper import analytics
from smskeeper.chunk_features import ChunkFeatures

logger = logging.getLogger(__name__)


class CompleteTodoMostRecentAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_COMPLETE_TODO_MOST_RECENT

	# things that match this RE will get a boost for complete
	# Is the same in specific, could consolidate
	# NOTE: Make sure there's a space after these words, otherwise "printed" will match
	beginsWithRe = r'^(done|check off) '

	def getScore(self, chunk, user):
		score = 0.0

		cleanedText = msg_util.cleanedDoneCommand(chunk.normalizedTextWithoutTiming(user))
		interestingWords = msg_util.getInterestingWords(cleanedText)

		justNotified = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_REMINDER) or user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_DIGEST) or (user.state == keeper_constants.STATE_REMINDER_SENT)

		regexHit = msg_util.done_re.search(chunk.normalizedText()) is not None
		entries = entry_util.fuzzyMatchEntries(user, ' '.join(interestingWords), 60)

		if regexHit and len(interestingWords) == 0 and len(entries) == 0:
			if justNotified:
				score = 0.9
			else:
				score = 0.7

		if regexHit and niceties.getNicety(' '.join(interestingWords)):
			score = 0.6

		if chunk.getNattyResult(user):
			score = 0.0

		if CompleteTodoMostRecentAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		entries = user.getLastEntries()

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

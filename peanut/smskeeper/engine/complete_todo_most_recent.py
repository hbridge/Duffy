import logging

from smskeeper import msg_util, sms_util, entry_util
from smskeeper import keeper_constants
from .action import Action

logger = logging.getLogger(__name__)


class CompleteTodoMostRecentAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_COMPLETE_TODO_MOST_RECENT

	def getScore(self, chunk, user):
		score = 0.0

		cleanedText = msg_util.cleanedDoneCommand(chunk.normalizedText())
		interestingWords = msg_util.getInterestingWords(cleanedText)

		justNotified = (user.state == keeper_constants.STATE_REMINDER_SENT)
		regexHit = msg_util.done_re.search(chunk.normalizedText()) is not None
		entries = entry_util.fuzzyMatchEntries(user, ' '.join(interestingWords), 60)

		if regexHit and len(interestingWords) < 2 and len(entries) == 0:
			if justNotified:
				score = 0.9
			else:
				score = 0.7

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

		msgBack = None
		if len(entries) == 1:
			msgBack = "Nice! Checked that off :white_check_mark:"
		elif len(entries) > 1:
			msgBack = "Nice! Checked those off :white_check_mark:"

		if msgBack:
			sms_util.sendMsg(user, msgBack)

		return True

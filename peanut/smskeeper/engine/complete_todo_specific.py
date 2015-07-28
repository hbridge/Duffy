import logging

from smskeeper import msg_util, entry_util, sms_util, actions
from smskeeper import keeper_constants
from smskeeper import analytics
from .action import Action

logger = logging.getLogger(__name__)


class CompleteTodoSpecificAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_COMPLETE_TODO_SPECIFIC

	def getScore(self, chunk, user):
		score = 0.0

		cleanedText = msg_util.cleanedDoneCommand(chunk.normalizedTextWithoutTiming(user))
		interestingWords = msg_util.getInterestingWords(cleanedText)

		regexHit = msg_util.done_re.search(chunk.normalizedText()) is not None
		bestEntries = entry_util.fuzzyMatchEntries(user, ' '.join(interestingWords), 80)

		if len(bestEntries) > 0 and len(interestingWords) >= 2:
			score = 0.3

		if regexHit and len(interestingWords) >= 2:
			score = 0.5

		if regexHit and len(bestEntries) > 0:
			score = 0.9

		if chunk.getNattyResult(user):
			score = 0.0

		if CompleteTodoSpecificAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

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

import logging

from smskeeper import entry_util, msg_util
from smskeeper import keeper_constants
from .changetime import ChangetimeAction

logger = logging.getLogger(__name__)


class ChangetimeSpecificAction(ChangetimeAction):
	ACTION_CLASS = keeper_constants.CLASS_CHANGETIME_SPECIFIC

	def getScore(self, chunk, user):
		score = 0.0

		nattyResult = chunk.getNattyResult(user)
		bestEntries = self.getEntriesToExecuteOn(chunk, user)
		regexHit = self.snoozeRegex.search(chunk.normalizedText()) is not None
		justNotified = (user.last_state == "remindersent")

		if regexHit and len(bestEntries) > 0:
			if justNotified:
				score = 0.6
			else:
				score = 0.3

		if nattyResult and len(bestEntries) > 0:
			if justNotified:
				score = 0.9
			else:
				score = 0.7

		if ChangetimeSpecificAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	# execute is in the parent ChangetimeAction
	def getEntriesToExecuteOn(self, chunk, user):
		msg = chunk.normalizedTextWithoutTiming(user)

		msg = msg_util.cleanedReminder(msg)
		msg = msg_util.cleanedSnoozeCommand(msg)

		entries = entry_util.fuzzyMatchEntries(user, chunk.normalizedTextWithoutTiming(user), 80)
		entries = filter(lambda x: not x.hidden, entries)
		return entries

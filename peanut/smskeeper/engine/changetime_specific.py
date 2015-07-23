import logging

from smskeeper import entry_util, reminder_util, actions, sms_util, msg_util
from smskeeper import keeper_constants
from .action import Action

logger = logging.getLogger(__name__)


class ChangetimeSpecificAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_CHANGETIME_SPECIFIC

	def getScore(self, chunk, user):
		score = 0.0

		nattyResult = chunk.getNattyResult(user)
		bestEntries = self.getBestEntries(chunk, user)
		justNotified = (user.last_state == "remindersent")

		if nattyResult and len(bestEntries) > 0:
			if justNotified:
				score = 0.9
			else:
				score = 0.7

		if ChangetimeSpecificAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		entries = self.getBestEntries(chunk, user)

		if len(entries) == 0:
			logger.info("User %s: I think this is a changetime-specific command but couldn't find a good enough entry. kicking out" % (user.id))
			paused = actions.unknown(user, chunk.originalText, user.getKeeperNumber(), sendMsg=False)
			if not paused:
				msgBack = "Sorry, I'm not sure what entry you mean."
				sms_util.sendMsg(user, msgBack, None, user.getKeeperNumber())
		else:
			nattyResult = chunk.getNattyResult(user)
			if nattyResult is None:
				nattyResult = reminder_util.getDefaultNattyResult(chunk.originalText, user)

			for entry in entries:
				reminder_util.updateReminderEntry(user, nattyResult, chunk.originalText, entry, user.getKeeperNumber(), isSnooze=True)
			reminder_util.sendCompletionResponse(user, entries[0], False, user.getKeeperNumber())

		return True

	def getBestEntries(self, chunk, user):
		msg = chunk.normalizedTextWithoutTiming(user)

		msg = msg_util.cleanedReminder(msg)
		msg = msg_util.cleanedSnoozeCommand(msg)

		entries = entry_util.fuzzyMatchEntries(user, chunk.normalizedTextWithoutTiming(user), 80)
		return entries

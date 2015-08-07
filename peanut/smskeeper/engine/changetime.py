import logging

from smskeeper import reminder_util, actions, sms_util
from .action import Action

logger = logging.getLogger(__name__)


class ChangetimeAction(Action):
	snoozeRegex = r"\b(snooze|again)\b"

	def execute(self, chunk, user):
		entries = self.getEntriesToExecuteOn(chunk, user)
		snoozeRegexHit = chunk.matches(self.snoozeRegex)

		justNotified = (user.last_state == "remindersent")

		if len(entries) == 0:
			logger.info("User %s: I think this is a changetime command but couldn't find a good enough entry. kicking out" % (user.id))
			paused = actions.unknown(user, chunk.originalText, user.getKeeperNumber(), sendMsg=False)
			if not paused:
				msgBack = "Sorry, I'm not sure what entry you mean."
				sms_util.sendMsg(user, msgBack, None, user.getKeeperNumber())
		else:
			nattyResult = chunk.getNattyResult(user)
			if nattyResult is None:
				nattyResult = reminder_util.getDefaultNattyResult(chunk.originalText, user)
			else:
				# Note: Don't like this here, should it be done automatically?
				nattyResult = reminder_util.fillInWithDefaultTime(user, nattyResult)

			for entry in entries:
				# Snoozes are updated differently since we use the full natty result (instead of just swap out what the user typed in)
				isSnooze = (snoozeRegexHit or justNotified)
				reminder_util.updateReminderEntry(user, nattyResult, chunk.originalText, entry, user.getKeeperNumber(), isSnooze=isSnooze)

			needFollowup = not nattyResult.validTime()
			reminder_util.sendCompletionResponse(user, entries[0], needFollowup, user.getKeeperNumber())

		return True

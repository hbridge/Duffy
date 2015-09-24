import logging
import random

from smskeeper import reminder_util, actions, sms_util, keeper_constants, keeper_strings
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
			daytime = actions.unknown(user, chunk.originalText, user.getKeeperNumber(), keeper_constants.UNKNOWN_TYPE_CHANGETIME, sendMsg=False, doAlert=True)

			if not daytime:
				sms_util.sendMsg(user, random.choice(keeper_strings.ENTRY_NOT_FOUND_TEXT), None, user.getKeeperNumber())
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

			followups = []
			if not nattyResult.validTime():
				followups = [keeper_constants.FOLLOWUP_TIME]

			reminder_util.sendCompletionResponse(user, entries[0], followups, user.getKeeperNumber())

		return True

import logging
import re
import pytz
import datetime

from smskeeper import entry_util, reminder_util, actions, sms_util, msg_util
from smskeeper import keeper_constants
from .action import Action

from common import date_util

logger = logging.getLogger(__name__)


class ChangetimeMostRecentAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_CHANGETIME_MOST_RECENT

	snoozeRegex = re.compile(r"\b(snooze|again)\b", re.I)

	def getScore(self, chunk, user):
		score = 0.0

		nattyResult = chunk.getNattyResult(user)
		regexHit = self.snoozeRegex.search(chunk.normalizedText()) is not None

		justNotified = (user.state == keeper_constants.STATE_REMINDER_SENT)

		if nattyResult:
			cleanedText = msg_util.cleanedReminder(nattyResult.queryWithoutTiming)
		else:
			cleanedText = msg_util.cleanedReminder(chunk.normalizedText())
		interestingWords = msg_util.getInterestingWords(cleanedText)
		entries = entry_util.fuzzyMatchEntries(user, ' '.join(interestingWords), 80)

		if nattyResult and not regexHit:
			score = 0.2

		if not nattyResult and regexHit:
			score = 0.2

		if len(entries) == 0:
			if nattyResult and regexHit:
				if justNotified:
					score = 0.9
				else:
					score = 0.7

			if self.isFollowup(chunk, user):
				score = 0.9

		if ChangetimeMostRecentAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		entries = user.getLastEntries()

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
				reminder_util.updateReminderEntry(user, nattyResult, chunk.originalText, entry, user.getKeeperNumber(), isSnooze=True)
			reminder_util.sendCompletionResponse(user, entries[0], False, user.getKeeperNumber())

		return True

	def getLastActionTime(self, user):
		if user.getStateData(keeper_constants.LAST_ACTION_KEY):
			return datetime.datetime.utcfromtimestamp(user.getStateData(keeper_constants.LAST_ACTION_KEY)).replace(tzinfo=pytz.utc)
		else:
			return None

	# Returns True if this message has a valid time and it doesn't look like another remind command
	# If reminderSent is true, then we look for again or snooze which if found, we'll assume is a followup
	# Like "remind me again in 5 minutes"
	# If the message (without timing info) only is "remind me" then also is a followup due to "remind me in 5 minutes"
	# Otherwise False
	def isFollowup(self, chunk, user):
		now = date_util.now(pytz.utc)

		nattyResult = chunk.getNattyResult(user)

		if not nattyResult:
			return False

		cleanedText = msg_util.cleanedReminder(nattyResult.queryWithoutTiming)  # no "Remind me"
		lastActionTime = self.getLastActionTime(user)
		interestingWords = msg_util.getInterestingWords(cleanedText)
		isRecentAction = True if (lastActionTime and (now - lastActionTime) < datetime.timedelta(minutes=5)) else False

		# Covers cases where there the cleanedText is "in" or "around"
		if len(cleanedText) <= 2:
			logger.info("User %s: I think this is a followup to bc its less than 2 letters" % (user.id))
			return True
		# If they write "no, remind me sunday instead" then want to process as followup
		elif msg_util.startsWithNo(nattyResult.queryWithoutTiming):
			logger.info("User %s: I think this is a followup bc it starts with a No" % (user.id))
			return True
		elif len(interestingWords) == 0:
			logger.info("User %s: I think this is a followup bc there's no interesting words" % (user.id))
			return True
		elif isRecentAction and len(interestingWords) < 2:
			logger.info("User %s: I think this is a followup bc we updated it recently and <2 interesting words" % (user.id))
			return True

		return False

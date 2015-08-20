import logging
import pytz
import datetime

from smskeeper import entry_util, msg_util
from smskeeper import keeper_constants
from .changetime import ChangetimeAction

from common import date_util

logger = logging.getLogger(__name__)


class ChangetimeMostRecentAction(ChangetimeAction):
	ACTION_CLASS = keeper_constants.CLASS_CHANGETIME_MOST_RECENT

	basicRegex = r"\b(snooze|again|change)\b"
	beginsWithRegex = r'^(change|snooze|update|remind (me )?again) '

	def getScore(self, chunk, user):
		score = 0.0

		nattyResult = chunk.getNattyResult(user)
		basicRegexHit = chunk.matches(self.basicRegex)
		beginsWithRegexHit = chunk.matches(self.beginsWithRegex)

		justNotifiedReminder = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_REMINDER) or (user.state == keeper_constants.STATE_REMINDER_SENT)
		justNotifiedDigest = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_DIGEST)

		cleanedText = msg_util.cleanedReminder(chunk.normalizedTextWithoutTiming(user))
		interestingWords = msg_util.getInterestingWords(cleanedText)
		entries = entry_util.fuzzyMatchEntries(user, ' '.join(interestingWords), 80)

		if nattyResult and not basicRegexHit:
			score = 0.2

		if not nattyResult and basicRegexHit:
			score = 0.2

		if len(entries) == 0:
			if nattyResult and basicRegexHit:
				if justNotifiedReminder:
					score = 0.9
				elif justNotifiedDigest:
					score = 0.75
				else:
					score = 0.7

			if beginsWithRegexHit:
				score = 0.9

			if self.isFollowup(chunk, user):
				score = 0.9

		if ChangetimeMostRecentAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	# execute is in the parent ChangetimeAction
	def getEntriesToExecuteOn(self, chunk, user):
		entries = user.getLastEntries()
		entries = filter(lambda x: not x.hidden, entries)
		return entries

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

import logging

from smskeeper import keeper_constants
from .changetime import ChangetimeAction


logger = logging.getLogger(__name__)


class ChangetimeMostRecentAction(ChangetimeAction):
	ACTION_CLASS = keeper_constants.CLASS_CHANGETIME_MOST_RECENT

	def getScore(self, chunk, user, features):
		score = 0.0

		if features.hasTimingInfo and not features.hasChangeTimeWord:
			score = 0.2

		if not features.hasTimingInfo and features.hasChangeTimeWord:
			score = 0.2

		if features.numMatchingEntriesStrict == 0 and features.numLastNotifiedEntries > 0:
			if features.hasTimingInfo and features.hasChangeTimeWord:
				if features.wasRecentlySentMsgOfClassReminder:
					score = 0.9
				elif features.wasRecentlySentMsgOfClassDigest:
					score = 0.75
				else:
					score = 0.7

			if features.beginsWithChangeTimeWord:
				score = 0.9

			if features.isFollowup:
				score = 0.9

		if features.hasPhoneNumber:
			score = 0.0

		return score

	# execute is in the parent ChangetimeAction
	def getEntriesToExecuteOn(self, chunk, user, features):
		entries = user.getLastEntries()
		entries = filter(lambda x: not x.hidden, entries)
		return entries

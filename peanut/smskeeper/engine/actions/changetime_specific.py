import logging

from smskeeper import entry_util, msg_util
from smskeeper import keeper_constants
from .changetime import ChangetimeAction
from smskeeper.chunk_features import ChunkFeatures

logger = logging.getLogger(__name__)


class ChangetimeSpecificAction(ChangetimeAction):
	ACTION_CLASS = keeper_constants.CLASS_CHANGETIME_SPECIFIC

	def getScore(self, chunk, user):
		score = 0.0

		features = ChunkFeatures(chunk, user)

		bestEntries = self.getEntriesToExecuteOn(chunk, user)
		okEntries = self.getEntriesToExecuteOn(chunk, user, 65)
		justNotifiedEntries = user.getLastEntries()

		if features.beginsWithChangeTimeWord() and len(bestEntries) > 0:
			if len(set(bestEntries).intersection(set(justNotifiedEntries))) > 0:
				score = 0.6
			else:
				score = 0.3

		if features.hasTimingInfo() and len(bestEntries) > 0:
			if len(set(bestEntries).intersection(set(justNotifiedEntries))) > 0:
				score = 0.8
			else:
				score = 0.7

		if features.beginsWithChangeTimeWord() and features.hasTimingInfo() and len(okEntries) > 0:
			score = 0.95

		return score

	# execute is in the parent ChangetimeAction
	def getEntriesToExecuteOn(self, chunk, user, score=80):
		msg = chunk.normalizedTextWithoutTiming(user)

		msg = msg_util.cleanedReminder(msg)
		msg = msg_util.cleanedSnoozeCommand(msg)

		entries = entry_util.fuzzyMatchEntries(user, chunk.normalizedTextWithoutTiming(user), score)
		entries = filter(lambda x: not x.hidden, entries)
		return entries

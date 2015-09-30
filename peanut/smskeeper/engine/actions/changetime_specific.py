import logging

from smskeeper import keeper_constants
from .changetime import ChangetimeAction


logger = logging.getLogger(__name__)


class ChangetimeSpecificAction(ChangetimeAction):
	ACTION_CLASS = keeper_constants.CLASS_CHANGETIME_SPECIFIC

	def getScore(self, chunk, user, features):
		score = 0.0

		if features.beginsWithChangeTimeWord and features.numMatchingEntriesStrict > 0:
			if features.numEntriesJustNotifiedAbout > 0:
				score = 0.6
			else:
				score = 0.3

		if features.hasTimingInfo and features.numMatchingEntriesStrict > 0:
			if features.numEntriesJustNotifiedAbout > 0:
				score = 0.8
			else:
				score = 0.7

		if features.beginsWithChangeTimeWord and features.hasTimingInfo and features.numMatchingEntriesBroad > 0:
			score = 0.95

		return score

	# execute is in the parent ChangetimeAction
	def getEntriesToExecuteOn(self, chunk, user, features, score=80):
		entries = features.getMatchingEntriesBroad()
		entries = filter(lambda x: not x.hidden, entries)
		return entries

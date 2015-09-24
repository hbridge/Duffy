from smskeeper import keeper_constants
from smskeeper import analytics, chunk_features
from .action import Action


class SilentNicetyAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_SILENT_NICETY

	def getScore(self, chunk, user):
		score = 0.0
		features = chunk_features.ChunkFeatures(chunk, user)

		if features.numWords() <= 1:
			score = .3

		# We have both nicety and silent nicety right now...so make sure we don't think
		# we're a silent one if there's responses
		# Kinda hacky
		if features.hasAnyNicety() and features.hasSilentNicety():
			score = 0.4

			matchScore = features.nicetyMatchScore()
			if matchScore > .9:
				score = .95

		if SilentNicetyAction.HasHistoricalMatchForChunk(chunk):
			score = 0.5

		if chunk.isPartOfMultiChunk and chunk.lineNum == 0 and chunk.originalText.endswith(":"):
			score = 1.0

		return score

	def execute(self, chunk, user):
		# log that the user sent a nicety regardless of whether Keeper responds
		analytics.logUserEvent(
			user,
			"Sent Nicety",
			None
		)
		return True

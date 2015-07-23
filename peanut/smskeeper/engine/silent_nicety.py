from smskeeper import msg_util
from smskeeper import keeper_constants
from smskeeper import niceties
from smskeeper import analytics
from .action import Action


class SilentNicetyAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_SILENT_NICETY

	def getScore(self, chunk, user):
		score = 0.0

		nicety = niceties.getNicety(chunk.originalText)

		# We have both nicety and silent nicety right now...so make sure we don't think
		# we're a silent one if there's responses
		# Kinda hacky
		if nicety and nicety.isSilent():
			score = 1.0

		if SilentNicetyAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		# TODO(Derek): Remove this once reminder stuff has been moved over to new processing engine
		if msg_util.isDoneCommand(chunk.originalText):
			score = 0.0

		return score

	def execute(self, chunk, user):
		# log that the user sent a nicety regardless of whether Keeper responds
		analytics.logUserEvent(
			user,
			"Sent Nicety",
			None
		)
		return True

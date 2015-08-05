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

		if len(chunk.originalText.split(' ')) == 1:
			score = .3

		# We have both nicety and silent nicety right now...so make sure we don't think
		# we're a silent one if there's responses
		# Kinda hacky
		if nicety and nicety.isSilent():
			score = 0.5

		if SilentNicetyAction.HasHistoricalMatchForChunk(chunk):
			score = 0.5

		return score

	def execute(self, chunk, user):
		# log that the user sent a nicety regardless of whether Keeper responds
		analytics.logUserEvent(
			user,
			"Sent Nicety",
			None
		)
		return True

import logging

from smskeeper import sms_util
from smskeeper import keeper_constants
from smskeeper import niceties
from smskeeper import analytics
from .action import Action

logger = logging.getLogger(__name__)


class NicetyAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_NICETY

	def getScore(self, chunk, user, features):
		score = 0.0

		# We have both nicety and silent nicety right now...so make sure we don't think
		# we're a real one if there's no responses
		# Kinda hacky
		if features.hasAnyNicety and not features.hasSilentNicety:
			score = .6

			if features.nicetyMatchScore > .9:
				score = .95

		# TODO(Derek): Remove this once reminder stuff has been moved over to new processing engine
		if features.hasDoneWord:
			score = 0.0

		return score

	def execute(self, chunk, user, features):
		nicety = niceties.getNicety(chunk.originalText)

		if nicety is None:
			logger.error("User %s: Executing nicety but don't have a response to send" % (user.id))
		else:
			response = nicety.getResponse(user, {}, user.getKeeperNumber())
			if response:
				sms_util.sendMsg(user, response)

		# log that the user sent a nicety regardless of whether Keeper responds
		analytics.logUserEvent(
			user,
			"Sent Nicety",
			None
		)
		return True

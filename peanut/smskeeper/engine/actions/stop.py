from .action import Action
from smskeeper import sms_util
from smskeeper import keeper_constants, keeper_strings
from smskeeper import analytics


class StopAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_STOP

	def getScore(self, chunk, user, features):
		score = 0.0

		if features.hasStopPhrase:
			score = .9

		if StopAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user, features):
		user.setState(keeper_constants.STATE_STOPPED, saveCurrent=True, override=True)

		isSilent = chunk.matches('silent')
		if not isSilent:
			sms_util.sendMsg(
				user,
				keeper_strings.STOP_RESPONSE,
				stopOverride=True
			)

		analytics.logUserEvent(
			user,
			"Stop/Start",
			{
				"Action": "Stop",
				"Is Silent": isSilent,
			}
		)
		return True

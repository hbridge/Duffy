from .action import Action
import re
from smskeeper import sms_util
from smskeeper import keeper_constants
import time
from smskeeper import analytics


class StopAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_STOP

	stopRegex = re.compile(r"stop$|cancel( keeper)?$|leave me alone|stop .+ me|.*don't text me.*", re.I)

	def getScore(self, chunk, user):
		score = 0.0

		if self.stopRegex.match(chunk.normalizedText()) is not None:
			score = .9

		if StopAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		user.setState(keeper_constants.STATE_STOPPED, saveCurrent=True, override=True)

		sms_util.sendMsgs(
			user,
			[u"I won't txt you anymore \U0001F61E. If you didn't mean to do this, just type 'start'",
			u"I hate to see you go. Is there something I can do better? \U0001F423"], stopOverride=True)

		analytics.logUserEvent(
			user,
			"Stop/Start",
			{"Action": "Stop"}
		)
		return True

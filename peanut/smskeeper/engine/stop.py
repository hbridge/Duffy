from .action import Action
import re
from smskeeper import sms_util
from smskeeper import keeper_constants
import time
from smskeeper import analytics


class StopAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_STOP

	def getScore(self, chunk, user):
		stop_re = re.compile(r"stop$|cancel( keeper)?$|leave me alone|stop .+ me|.*don't text me.*", re.I)
		score = 0.0

		if stop_re.match(chunk.normalizedText()) is not None:
			score = .9

		if StopAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		sms_util.sendMsg(user, u"I won't txt you anymore \U0001F61E. If you didn't mean to do this, just type 'start'")

		if keeper_constants.isRealKeeperNumber(user.getKeeperNumber()):
			time.sleep(1)

		analytics.logUserEvent(
			user,
			"Stop/Start",
			{"Action": "Stop"}
		)

		user.setState(keeper_constants.STATE_STOPPED, saveCurrent=True, override=True)
		user.save()

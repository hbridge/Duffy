import pytz

from common import date_util, weather_util

from smskeeper import sms_util
from smskeeper import keeper_constants, analytics, keeper_strings
from .action import Action

import logging
logger = logging.getLogger(__name__)


class FetchWeatherAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FETCH_WEATHER

	def getScore(self, chunk, user, features):
		score = 0.0

		scoreVector = []
		scoreVector.append(0.8 if features.hasWeatherWord else 0)
		scoreVector.append(0.1 if features.isQuestion else 0)
		scoreVector.append(-0.5 if features.isBroadQuestion else 0)
		scoreVector.append(0.1 if features.containsToday else 0)

		logger.debug("User %d: fetch weather score vector: %s", user.id, scoreVector)
		score = sum(scoreVector)

		if FetchWeatherAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user, features):
		nattyResult = chunk.getNattyResult(user)

		if nattyResult and nattyResult.hadDate:
			date = nattyResult.utcTime
		else:
			date = date_util.now(pytz.utc)

		weatherPhrase = weather_util.getWeatherPhraseForZip(user, user.wxcode, date, dict())
		if weatherPhrase:
			sms_util.sendMsg(user, weatherPhrase)
		else:
			sms_util.sendMsg(user, keeper_strings.WEATHER_NOT_FOUND)

		analytics.logUserEvent(
			user,
			"Weather request",
			{
				"Date Specific": (nattyResult and nattyResult.hadDate),
			}
		)

		return True

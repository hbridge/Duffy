import pytz

from common import date_util, weather_util

from smskeeper import sms_util, chunk_features
from smskeeper import keeper_constants, analytics
from .action import Action

import logging
logger = logging.getLogger(__name__)


class FetchWeatherAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FETCH_WEATHER

	def getScore(self, chunk, user):
		score = 0.0

		features = chunk_features.ChunkFeatures(chunk, user)
		scoreVector = []
		scoreVector.append(0.8 if features.hasWeatherWord() else 0)
		scoreVector.append(0.1 if features.isQuestion() else 0)
		scoreVector.append(-0.5 if features.isBroadQuestion() else 0)
		scoreVector.append(0.1 if features.containsToday() else 0)

		logger.debug("User %d: fetch weather score vector: %s", user.id, scoreVector)
		score = sum(scoreVector)

		if FetchWeatherAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		nattyResult = chunk.getNattyResult(user)

		if nattyResult and nattyResult.hadDate:
			date = nattyResult.utcTime
		else:
			date = date_util.now(pytz.utc)

		weatherPhrase = weather_util.getWeatherPhraseForZip(user, user.wxcode, date, dict())
		if weatherPhrase:
			sms_util.sendMsg(user, weatherPhrase)
		else:
			sms_util.sendMsg(user, "I'm sorry, I don't know the weather right now")

		analytics.logUserEvent(
			user,
			"Weather request",
			{
				"Date Specific": nattyResult.hadDate
			}
		)

		return True

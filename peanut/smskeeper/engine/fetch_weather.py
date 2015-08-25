import pytz

from common import date_util, weather_util


from smskeeper import sms_util, chunk_features
from smskeeper import keeper_constants, analytics
from .action import Action


class FetchWeatherAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FETCH_WEATHER

	def getScore(self, chunk, user):
		score = 0.0

		features = chunk_features.ChunkFeatures(chunk, user)

		if features.hasWeatherWord():
			score = .9

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
			"Fetch Weather",
			{
			}
		)

		return True

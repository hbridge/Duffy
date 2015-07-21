import pytz
import re

from common import date_util, weather_util

from smskeeper import sms_util
from smskeeper import keeper_constants
from .action import Action


class FetchWeatherAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_FETCH_WEATHER

	def getScore(self, chunk, user):
		weather_re = re.compile(r"\bweather\b", re.I)
		score = 0.0

		if weather_re.search(chunk.normalizedText()) is not None:
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

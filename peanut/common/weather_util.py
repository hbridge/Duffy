# -*- coding: utf-8 -*-

import pywapi
import logging

from common import date_util

from smskeeper import keeper_constants

logger = logging.getLogger(__name__)

weatherCodes = {
	"0": u'\U0001F300',
	"1": u'\U0001F300',
	"2": u'\U0001F300\U0001F300',
	"3": u'\U000026A1\U000026A1\U00002614',
	"4": u'\U000026A1\U00002614',
	"5": u'\U0001F4A7\U00002744',
	"6": u'\U0001F4A7\U000026AA',
	"7": u'\U00002744\U000026AA',
	"8": u'\U0001F4A7',
	"9": u'\U00002614',
	"10": u'\U000026C4\U00002614',
	"11": u'\U00002614',
	"12": u'\U00002614',
	"13": u'\U00002744',
	"14": u'\U00002744\U0001F4A7',
	"15": u'\U00002744\U0001F4A8',
	"16": u'\U00002744',
	"17": u'\U0001F4A7\U00002614',
	"18": u'\U00002744',
	"19": u'\U0001F301',
	"20": u'\U0001F301',
	"21": u'\U0001F301',
	"22": u'\U0001F301',
	"23": u'\U0001F4A8\U0001F4A8',
	"24": u'\U0001F4A8',
	"25": u'\U000026C4',
	"26": u'\U00002601\U00002601',
	"27": u'\U00002601\U00002601',
	"28": u'\U00002601\U000026C5',
	"29": u'\U0001F30C\U00002601',
	"30": u'\U000026C5',
	"31": u'\U0001F30C\U0001F319',
	"32": u'\U0001F31E\U0001F31E',
	"33": u'\U0001F30C',
	"34": u'\U0001F31E',
	"35": u'\U00002614',
	"36": u'\U0001F630\U0001F4A6',
	"37": u'\U000026A1\U00002614',
	"38": u'\U000026A1\U00002614',
	"39": u'\U000026A1\U00002614',
	"40": u'\U00002614',
	"41": u'\U00002744\U00002744\U00002744',
	"42": u'\U00002744\U0001F4A7',
	"43": u'\U00002744\U00002744\U00002744',
	"44": u'\U000026C5',
	"45": u'\U000026A1\U00002614',
	"46": u'\U00002744\U0001F4A7',
	"47": u'\U000026A1\U00002614',
	"3200": u'\U00002601',
}


def getWeatherPhraseForZip(user, wxcode, utcDate, weatherDataCache):
	if wxcode in weatherDataCache and user.temp_format in weatherDataCache[wxcode]:
		data = weatherDataCache[wxcode]
	else:
		try:
			data = getWeatherForWxCode(wxcode, user.temp_format)
			weatherDataCache[wxcode] = data
		except Exception, e:
			logger.error("User %s: Got exception %s when fetching weather for %s" % (user.id, e, wxcode))
			data = None

	if data:
		dataForUser = data[user.temp_format]
		if "forecasts" in dataForUser:
			now = date_util.now(user.getTimezone())
			tzAwareDate = utcDate.astimezone(user.getTimezone())

			if tzAwareDate.day == now.day:
				dayTerm = "Today"
				dayIndex = 0
			else:
				dayTerm = tzAwareDate.strftime("%A")
				dayDiff = tzAwareDate.date() - now.date()
				dayIndex = dayDiff.days

			if dayIndex >= len(dataForUser["forecasts"]):
				logger.error("User %s: DayIndex %s is to large for data %s" % (user.id, dayIndex, dataForUser["forecasts"]))
				return "Sorry, I don't know the weather for that day"

			tempFormatStr = ""
			if user.temp_format == keeper_constants.TEMP_FORMAT_METRIC:
				tempFormatStr = u"°C"

			return "%s's forecast: %s %s | High %s%s and low %s%s" % (dayTerm, dataForUser["forecasts"][dayIndex]["text"], weatherCodes[dataForUser["forecasts"][dayIndex]["code"]], dataForUser["forecasts"][dayIndex]["high"], tempFormatStr, dataForUser["forecasts"][dayIndex]["low"], tempFormatStr)
		else:
			logger.error("User %s: Didn't find forecast for zip %s" % (user.id, wxcode))
			return None
	else:
		logger.error("User %s: Didn't find forecast for zip %s" % (user.id, wxcode))
		return None


def getWeatherForWxCode(wxcode, tempFormat):
	return {tempFormat: pywapi.get_weather_from_yahoo(wxcode, tempFormat)}

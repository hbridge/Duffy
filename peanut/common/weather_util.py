import pywapi
import logging

from common import date_util

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
	if wxcode in weatherDataCache:
		data = weatherDataCache[wxcode]
	else:
		try:
			data = getWeatherForZip(wxcode)
			weatherDataCache[wxcode] = data
		except:
			data = None

	if data:
		if "forecasts" in data:
			now = date_util.now(user.getTimezone())
			txAwareDate = utcDate.astimezone(user.getTimezone())

			if txAwareDate.day == now.day:
				dayTerm = "Today"
				dayIndex = 0
			else:
				dayTerm = txAwareDate.strftime("%A")
				dayDiff = txAwareDate - now
				dayIndex = dayDiff.days

			if dayIndex >= len(data["forecasts"]):
				logger.error("User %s: DayIndex %s is to large for data %s" % (user.id, dayIndex, data["forecasts"]))
				return "Sorry, I don't know the weather for that day"

			return "%s's forecast: %s %s | High %s and low %s" % (dayTerm, data["forecasts"][dayIndex]["text"], weatherCodes[data["forecasts"][dayIndex]["code"]], data["forecasts"][dayIndex]["high"], data["forecasts"][dayIndex]["low"])
		else:
			logger.error("User %s: Didn't find forecast for zip %s" % (user.id, wxcode))
			return None
	else:
		return None


def getWeatherForZip(wxcode):
	return pywapi.get_weather_from_yahoo(wxcode, 'imperial')

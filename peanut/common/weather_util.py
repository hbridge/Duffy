import pywapi


def getWeatherForZip(zipCode):
	pywapi.get_weather_from_yahoo(zipCode, 'imperial')

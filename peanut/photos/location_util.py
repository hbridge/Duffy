import json
import urllib2
import urllib

"""
	Makes call to twofishes and gets back raw json
"""
def getDataFromTwoFishes(lat, lon):
	queryStr = "%s,%s" % (lat, lon)
	twoFishesParams = { "ll" : queryStr }

	twoFishesUrl = "http://demo.twofishes.net/?%s" % (urllib.urlencode(twoFishesParams)) 

	twoFishesResult = urllib2.urlopen(twoFishesUrl).read()

	if (twoFishesResult):
		return twoFishesResult
	return None
import json
import urllib2
import urllib
import sys
import os
import logging

if "/home/derek/Duffy/peanut" not in sys.path:
	 sys.path.insert(0, "/home/derek/Duffy/peanut")

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from bulk_update.helper import bulk_update

logger = logging.getLogger(__name__)

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

def chunks(l, n):
	""" Yield successive n-sized chunks from l.
	"""
	for i in xrange(0, len(l), n):
		yield l[i:i+n]
		
def getLatLon(photo):
	if photo.metadata:
		metadata = json.loads(photo.metadata)
		if "{GPS}" in metadata:
			gpsData = metadata["{GPS}"]
			lat = lon = None

			if "Latitude" in gpsData:
				lat = gpsData["Latitude"]
				if gpsData["LatitudeRef"] == "S":
					lat = lat * -1
			if "Longitude" in gpsData:
				lon = gpsData["Longitude"]
				if gpsData["LongitudeRef"] == "W":
					lon = lon * -1
			return (lat, lon)
	return None

def getCity(twoFishesResult):
	for entry in twoFishesResult:
		if "feature" in entry:
			feature = entry["feature"]
			if "woeType" in feature:
				if int(feature["woeType"]) == 7:
					return feature["displayName"]

	return None

"""
	Static method for populating extra info like twoFishes.

	Static so it can be called in its own thread.
"""
def populateLocationInfo(photos):
	latLonList = list()
	photosWithLL = list()
	for photo in photos:
		ll = getLatLon(photo)
		if (ll):
			latLonList.append(ll)
			photosWithLL.append(photo)

	twoFishesResults = getDataFromTwoFishesBulk(latLonList)

	photosToUpdate = list()
	for i, photo in enumerate(photosWithLL):
		city = getCity(twoFishesResults[i])
		if city:
			photo.location_city = city
		photo.twofishes_data = json.dumps(twoFishesResults[i])
		photosToUpdate.append(photo)

	if len(photosToUpdate) == 1:
		photosToUpdate[0].save()
	else:
		bulk_update(photosToUpdate)

	logger.info("Wrote out " + str(len(photosToUpdate)) + " twofish entries")

"""
	Makes call to twofishes and gets back raw json
"""
def getDataFromTwoFishesBulk(latLonList):
	resultList = list()

	for chunk in chunks(latLonList, 25):
		params = list()
		for latLonPair in chunk:
			params.append("ll=%s,%s" % latLonPair)
		params.append("method=bulkrevgeo")

		twoFishesParams = '&'.join(params)

		twoFishesUrl = "http://demo.twofishes.net/?%s" % (twoFishesParams)

		twoFishesResultJson = urllib2.urlopen(twoFishesUrl).read()
		
		if (twoFishesResultJson):
			twoFishesResult = json.loads(twoFishesResultJson)
			for batch in twoFishesResult["interpretationIndexes"]:
				result = list()
				for index in batch:
					result.append(twoFishesResult["interpretations"][index])
				resultList.append(result)
	return resultList
	return None

"""
	This is used only for testing purposes
"""
def main(argv):
	l = [(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),(34,-120), (34, 56),]
	
	print len(l)
	results = getDataFromTwoFishesBulk(l)
	print len(results)
	#for result in results:
		#print(result)

if __name__ == "__main__":
	main(sys.argv[1:])
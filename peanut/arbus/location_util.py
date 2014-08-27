import json
import urllib2
import urllib
import sys
import os
import logging

from django.contrib.gis.geos import fromstr


from common.models import Photo

from arbus import image_util
from common import bulk_updater

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



# copied from https://gist.github.com/erans/983821
def _get_if_exist(data, key):
	if key in data:
		return data[key]
		
	return None
	
def _convert_to_degress(value):
	"""Helper function to convert the GPS coordinates stored in the EXIF to degress in float format"""
	d0 = value[0][0]
	d1 = value[0][1]
	d = float(d0) / float(d1)
 
	m0 = value[1][0]
	m1 = value[1][1]
	m = float(m0) / float(m1)
 
	s0 = value[2][0]
	s1 = value[2][1]
	s = float(s0) / float(s1)
 
	return d + (m / 60.0) + (s / 3600.0)
 

"""
	Looks for location info from passed in exif data.
	Uses data from image_util.getExifData

	Returns back the lat, lon as a tuple
	If not found, returns (None, None)
"""
def getLatLonFromExif(exif_data):
	"""Returns the latitude and longitude, if available, from the provided exif_data (obtained through get_exif_data above)"""
	lat = None
	lon = None
 
	if "GPSInfo" in exif_data:		
		gps_info = exif_data["GPSInfo"]
 
		gps_latitude = _get_if_exist(gps_info, "GPSLatitude")
		gps_latitude_ref = _get_if_exist(gps_info, 'GPSLatitudeRef')
		gps_longitude = _get_if_exist(gps_info, 'GPSLongitude')
		gps_longitude_ref = _get_if_exist(gps_info, 'GPSLongitudeRef')
 
		if gps_latitude and gps_latitude_ref and gps_longitude and gps_longitude_ref:
			lat = _convert_to_degress(gps_latitude)
			if gps_latitude_ref != "N":                     
				lat = 0 - lat
 
			lon = _convert_to_degress(gps_longitude)
			if gps_longitude_ref != "E":
				lon = 0 - lon
 
	return (lat, lon)


"""
	Looks for lat/lon data in metadata, then if told, looks at exif info in the actual file

	Returns back the lat, lon as a tuple
	If not found, returns (None, None)
"""
def getLatLonAccuracyFromExtraData(photo, tryFile=False):
	if photo.metadata:
		metadata = json.loads(photo.metadata)
		if "{GPS}" in metadata:
			gpsData = metadata["{GPS}"]
			lat = lon = accuracy = None

			if "Latitude" in gpsData and gpsData['Latitude'] > 0:
				lat = gpsData["Latitude"]
				if gpsData["LatitudeRef"] == "S":
					lat = lat * -1
			if "Longitude" in gpsData and gpsData['Longitude'] > 0:
				lon = gpsData["Longitude"]
				if gpsData["LongitudeRef"] == "W":
					lon = lon * -1
			if "{Exif}" in metadata and "UserComment" in metadata["{Exif}"]:
				userComment = metadata["{Exif}"]["UserComment"]

				# userComment should be of the form  "(old Data)=|=accuracy=40.0000"
				if "accuracy" in userComment:
					accuracyArray = userComment.split("accuracy=")
					if len(accuracyArray) > 1:
						accuracy = int(float(accuracyArray[-1]))

			if lat and lon:
				return (lat, lon, accuracy)
			else:
				logger.error("Thought I should have found GPS data but didn't in photo %s and metadata: %s" % (photo.id, metadata))
				return (None, None, None)
		
	if (tryFile):
		exif = image_util.getExifData(photo)
		
		lat, lon = getLatLonFromExif(exif)
		if lat and lon:
			return (lat, lon)

	return (None, None)

def getCity(twoFishesResult):
	for entry in twoFishesResult:
		if "feature" in entry:
			feature = entry["feature"]
			if "woeType" in feature:
				if int(feature["woeType"]) == 7:
					return feature["displayName"]

	return None

def populateLocationInfoByIds(photoIds):
	photos = Photo.objects.filter(id__in = photoIds)
	return populateLocationInfo(photos)


"""
	Static method for populating extra info like twoFishes.

	Static so it can be called in its own thread.
"""
def populateLocationInfo(photos):
	latLonList = list()
	photosWithLL = list()
	photosToUpdate = list()
	logger.info("Starting populateLocationInfo with %s photos" % len(photos))
	for photo in photos:
		if photo.location_point:
			lat, lon = (photo.location_point.y, photo.location_point.x)
		else:
			lat, lon, accuracy = getLatLonAccuracyFromExtraData(photo)
			if lat and lon:
				# Something must have gone wrong at intake, lets fix it up
				photo.location_point = fromstr("POINT(%s %s)" % (lon, lat))
				photo.location_accuracy_meters = accuracy
				logger.warning("Fixed up photo %s which didn't have location point, now %s %s" % (photo.id, lon, lat))

		if lat and lon:
			latLonList.append((lat, lon))
			photosWithLL.append(photo)
		else:
			photo.twofishes_data = json.dumps({})
			photosToUpdate.append(photo)

	logger.info("Found %s lat/lon" % len(latLonList))

	twoFishesResults = getDataFromTwoFishesBulk(latLonList)

	logger.info("Got back %s results from twofishes" % len(twoFishesResults))

	for i, photo in enumerate(photosWithLL):
		city = getCity(twoFishesResults[i])
		if city:
			photo.location_city = city

		formattedResult = {"interpretations": twoFishesResults[i]}
		photo.twofishes_data = json.dumps(formattedResult)
		photosToUpdate.append(photo)

	logger.info("Updating %s photos" % len(photosToUpdate))

	Photo.bulkUpdate(photosToUpdate, ["twofishes_data", "location_city", "location_point", "location_accuracy_meters"])

	return len(photosToUpdate)

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

		logger.debug("Requesting URL:  %s" % twoFishesUrl)
		twoFishesResultJson = urllib2.urlopen(twoFishesUrl).read()
		
		if (twoFishesResultJson):
			twoFishesResult = json.loads(twoFishesResultJson)
			for batch in twoFishesResult["interpretationIndexes"]:
				result = list()
				for index in batch:
					result.append(twoFishesResult["interpretations"][index])
				resultList.append(result)
	return resultList

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
import math
from math import radians, cos, sin, asin, sqrt

from peanut.settings import constants

def haversine(lon1, lat1, lon2, lat2):
	"""
	Calculate the great circle distance between two points 
	on the earth (specified in decimal degrees)
	"""
	# convert decimal degrees to radians 
	lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
	# haversine formula 
	dlon = lon2 - lon1 
	dlat = lat2 - lat1 
	a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
	c = 2 * asin(sqrt(a)) 
	km = 6367 * c
	return km

def getDistanceBetweenPhotos(photo1, photo2):
	if photo1.location_point and photo2.location_point:
		return int(haversine(photo1.location_point.x, photo1.location_point.y, photo2.location_point.x, photo2.location_point.y) * 1000)
	return None

def getDistanceBetweenStrands(strand1, strand2):
	"""
	lowestDistance = None
	for photo1 in strand1.photos.all():
		if photo1.location_point:
			for photo2 in strand2.photos.all():
				if photo2.location_point:
					dist = int(haversine(photo1.location_point.x, photo1.location_point.y, photo2.location_point.x, photo2.location_point.y) * 1000)
					if not lowestDistance or dist < lowestDistance:
						lowestDistance = dist

	return lowestDistance
	"""
	if strand1.location_point and strand2.location_point:
		return int(haversine(strand1.location_point.x, strand1.location_point.y, strand2.location_point.x, strand2.location_point.y) * 1000)
	return None


def getDistanceBetweenStrandAndLocationRecord(strand, locationRecord):
	"""
	lowestDistance = None
	for photo in strand.photos.all():
		if photo.location_point:
			dist = int(haversine(photo.location_point.x, photo.location_point.y, locationRecord.point.x, locationRecord.point.y) * 1000)
			if not lowestDistance or dist < lowestDistance:
				lowestDistance = dist

	return lowestDistance
	"""
	if strand.location_point:
		return int(haversine(strand.location_point.x, strand.location_point.y, locationRecord.point.x, locationRecord.point.y) * 1000)
	return None

def getDistanceToPhoto(lon, lat, photo):
	geoDistance = int(haversine(lon, lat, photo.location_point.x, photo.location_point.y) * 1000)
	return geoDistance
	
"""

	Returns: (photo, timeDistance, geoDistance)
"""
def getNearbyPhotos(baseTime, lon, lat, photosCache, filterUserId=None, filterPhotoId=None, secondsWithin=3*60*60, distanceWithin=constants.DISTANCE_WITHIN_METERS_FOR_ROUGH_NEIGHBORING):
	nearbyPhotos = list()

	for photo in photosCache:
		timeDistance = baseTime - photo.time_taken

		if ((filterPhotoId and filterPhotoId == photo.id) or 
			 (filterUserId and filterUserId == photo.user_id)):
			continue

		# If this photo is within the timerange and isn't a photo belonging to the filtered user and 
		if (int(math.fabs(timeDistance.total_seconds())) < secondsWithin):
			geoDistance = int(haversine(lon, lat, photo.location_point.x, photo.location_point.y) * 1000)
			if geoDistance < distanceWithin:
				nearbyPhotos.append((photo, timeDistance, geoDistance))
	return nearbyPhotos

def getNearbyPhotosToPhoto(refPhoto, photosCache):
	return getNearbyPhotos(	refPhoto.time_taken,
							refPhoto.location_point.x,
							refPhoto.location_point.y, 
							photosCache,
							filterUserId = refPhoto.user_id,
							filterPhotoId = refPhoto.id)

"""
	Go through the user list and pick out any users that are within
"""
def getNearbyUsers(lon, lat, users, filterUserId=None, distanceWithin=constants.DISTANCE_WITHIN_METERS_FOR_ROUGH_NEIGHBORING, accuracyWithin = 200):
	nearbyUsers = list()
	for user in users:
		if user.id != filterUserId and user.last_location_point:
			geoDistance = int(haversine(lon, lat, user.last_location_point.x, user.last_location_point.y) * 1000)
			if geoDistance < distanceWithin:
				if accuracyWithin:
					if user.last_location_accuracy and user.last_location_accuracy <= accuracyWithin:
						nearbyUsers.append(user)
				else:
					nearbyUsers.append(user)
	return nearbyUsers
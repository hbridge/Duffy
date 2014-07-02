import math
from math import radians, cos, sin, asin, sqrt

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


"""

	Returns: (photo, timeDistance, geoDistance)
"""
def getNearbyPhotos(baseTime, lon, lat, photosCache, filterUserId=None, filterPhotoId=None, secondsWithin=3*60*60, distanceWithin=100):
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
def getNearbyUsers(lon, lat, users, filterUserId=None, distanceWithin=100):
	nearbyUsers = list()
	for user in users:
		if user.id != filterUserId and user.last_location_point:
			geoDistance = int(haversine(lon, lat, user.last_location_point.x, user.last_location_point.y) * 1000)
			if geoDistance < distanceWithin:
				nearbyUsers.append(user)
	return nearbyUsers
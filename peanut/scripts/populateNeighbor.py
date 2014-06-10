#!/usr/bin/python
import sys, os
import time, datetime
import logging
import math
from math import radians, cos, sin, asin, sqrt

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.db.models import Count

from bulk_update.helper import bulk_update

from peanut import settings
from common.models import Photo, User, Neighbor
from arbus import cluster_util

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


def processWithExisting(existingRows, newRows):
	existing = dict()
	rowsToCreate = list()

	for row in existingRows:
		id1 = row.photo_1_id
		id2 = row.photo_2_id

		if id1 not in existing:
			existing[id1] = dict()
		existing[id1][id2] = True

	for newRow in newRows:
		id1 = newRow.photo_1_id
		id2 = newRow.photo_2_id

		if id1 in existing and id2 in existing[id1]:
			pass
		else:
			rowsToCreate.append(newRow)
	return rowsToCreate

def getAllPhotoIds(rows):
	photoIds = list()
	for row in rows:
		photoIds.append(row.photo_1_id)
		photoIds.append(row.photo_2_id)

	return set(photoIds)

def getUniqueRows(rows):
	uniqueRows = dict()

	for row in rows:
		id = (row.photo_1.id, row.photo_2.id)
		if id not in uniqueRows:
			uniqueRows[id] = row
	return uniqueRows.values()

def getNearbyPhotos(refPhoto, photosCache):
	nearbyPhotos = list()

	for photo in photosCache:
		timeDistance = refPhoto.time_taken - photo.time_taken

		if refPhoto.id != photo.id and refPhoto.user_id != photo.user_id and int(math.fabs(timeDistance.total_seconds())) < 3*60*60:
			geoDistance = int(haversine(refPhoto.location_point.x, refPhoto.location_point.y, photo.location_point.x, photo.location_point.y) * 1000)
			if geoDistance < 100:
				nearbyPhotos.append((refPhoto, photo, timeDistance, geoDistance))
	return nearbyPhotos
	
def main(argv):
	maxFilesAtTime = 100
	logger = logging.getLogger(__name__)
	
	logger.info("Starting... ")
	while True:
		photos = Photo.objects.all().exclude(user_id=1).exclude(thumb_filename=None).filter(neighbored_time=None).exclude(time_taken=None).exclude(location_point=None).filter(user__product_id=1).order_by('-time_taken')[:maxFilesAtTime]

		if len(photos) > 0:
			rowsToWrite = list()
			photos = list(photos)

			timeHigh = photos[0].time_taken + datetime.timedelta(hours=3)
			timeLow = photos[-1].time_taken - datetime.timedelta(hours=3)

			photosCache = Photo.objects.filter(time_taken__gte=timeLow).filter(time_taken__lte=timeHigh).exclude(location_point=None).filter(user__product_id=1)

			for refPhoto in photos:
				nearbyPhotos = getNearbyPhotos(refPhoto, photosCache)
				
				for nearbyPhotoData in nearbyPhotos:
					refPhoto, nearbyPhoto, timeDistance, geoDistance = nearbyPhotoData
				
					if (refPhoto.id < nearbyPhoto.id):
						photo_1 = refPhoto
						photo_2 = nearbyPhoto
					else:
						photo_1 = nearbyPhoto
						photo_2 = refPhoto
											
					neighbor = Neighbor(photo_1 = photo_1,
							photo_2 = photo_2,
							user_1_id = photo_1.user_id,
							user_2_id = photo_2.user_id,
							time_distance_sec = int(math.fabs(timeDistance.total_seconds())),
							geo_distance_m = geoDistance)
					rowsToWrite.append(neighbor)
					print neighbor
					
				refPhoto.neighbored_time = datetime.datetime.now()

			uniqueRows = getUniqueRows(rowsToWrite)

			allIds = getAllPhotoIds(uniqueRows)
			existingRows = Neighbor.objects.filter(photo_1__in=allIds).filter(photo_2__in=allIds)
			rowsToCreate = processWithExisting(existingRows, uniqueRows)

			Neighbor.objects.bulk_create(rowsToCreate)
			Photo.bulkUpdate(photos, ["neighbored_time"])
			
			logger.info("Wrote out %s new neighbor entries for %s photos" % (len(uniqueRows), len(photos)))
			
		else:
			time.sleep(1)	

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/neighbor.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
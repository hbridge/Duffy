#!/usr/bin/python
import sys, os
import time, datetime
import logging
import math

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

from django.db.models import Count

from peanut.settings import constants
from common.models import Photo, User, Neighbor

from strand import geo_util
import strand.notifications_util as notifications_util

logger = logging.getLogger(__name__)

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

def cleanName(str):
	return str.split(' ')[0].split("'")[0]

def sendNotifications(neighbors):
	msgType = constants.NOTIFICATIONS_NEW_PHOTO_ID
	customPayload = {'view': constants.NOTIFICATIONS_APP_VIEW_GALLERY}
	
	# Grab logs from last 30 seconds (default) then grab the last time they were notified
	notificationLogs = notifications_util.getNotificationLogs()
	notificationsById = notifications_util.getNotificationsForTypeById(notificationLogs, msgType)

	# This is a dict with the user as the key and a list of other users w photos as the value
	usersToNotify = dict()

	for neighbor in neighbors:
		# If photo2 time is after photo1, we want to notify user1 since they have the older one
		# Else we want to notify user2
		if neighbor.photo_1.time_taken < neighbor.photo_2.time_taken:
			user = neighbor.user_1
			otherUser = neighbor.user_2
		else:
			user = neighbor.user_2
			otherUser = neighbor.user_1

		if user not in usersToNotify:
			usersToNotify[user] = list()
		usersToNotify[user].append(otherUser)

	for user, otherUsers in usersToNotify.iteritems():
		otherUsers = set(otherUsers)

		names = list()
		for otherUser in otherUsers:
			names.append(cleanName(otherUser.display_name))

		msg = " & ".join(names) + " added new photos!"

		# If the user doesn't show up in the array then they haven't been notified in that time period
		if user.id not in notificationsById:
			logger.debug("Sending message '%s' to user %s" % (msg, user))
			notifications_util.sendNotification(user, msg, msgType, customPayload)
		else:
			logger.debug("Was going to send message '%s' to user %s but they were messaged recently" % (msg, user))
	
def main(argv):
	maxFilesAtTime = 100
	
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
				nearbyPhotos = geo_util.getNearbyPhotosToPhoto(refPhoto, photosCache)
				
				for nearbyPhotoData in nearbyPhotos:
					nearbyPhoto, timeDistance, geoDistance = nearbyPhotoData
				
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
					logger.debug("Writing out neighbor row %s" % (neighbor))
					
				refPhoto.neighbored_time = datetime.datetime.now()

			uniqueRows = getUniqueRows(rowsToWrite)

			allIds = getAllPhotoIds(uniqueRows)
			existingRows = Neighbor.objects.filter(photo_1__in=allIds).filter(photo_2__in=allIds)
			rowsToCreate = processWithExisting(existingRows, uniqueRows)

			Neighbor.objects.bulk_create(rowsToCreate)
			Photo.bulkUpdate(photos, ["neighbored_time"])
			
			logger.info("Wrote out %s new neighbor entries for %s photos" % (len(uniqueRows), len(photos)))

			sendNotifications(rowsToCreate)
		else:
			time.sleep(1)	

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/neighbor.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

from django.db.models import Count
from django.db.models import Q

from peanut.settings import constants
from common.models import NotificationLog, Photo, User, PhotoAction, Strand

from strand import notifications_util, geo_util, strands_util, friends_util

logger = logging.getLogger(__name__)

"""
	Look through all recent photos from last 30 minutes and see if any users have a 
	  last_location_point near there...and haven't been notified recently about that user
"""
def sendJoinStrandNotification(now, joinStrandWithin, joinStrandLimitGpsUpdatedWithin, notificationLogsCache):
	msgType = constants.NOTIFICATIONS_JOIN_STRAND_ID

	newPhotosStartTimeCutoff = now - joinStrandWithin
	notificationsById = notifications_util.getNotificationsForTypeByIds(notificationLogsCache, [msgType, constants.NOTIFICATIONS_NEW_PHOTO_ID], newPhotosStartTimeCutoff)

	# 30 minute cut off for join strand messages
	joinStrandStartTimeCutoff = now - joinStrandWithin
	strands = Strand.objects.select_related().filter(last_photo_time__gt=joinStrandStartTimeCutoff)
	
	frequencyOfGpsUpdatesCutoff = now - joinStrandLimitGpsUpdatedWithin
	users = User.objects.filter(product_id=1).filter(last_location_timestamp__gt=frequencyOfGpsUpdatesCutoff)

	for user in users:
		friendsIds = friends_util.getFriendsIds(user.id)
		joinableStrandPhotos = strands_util.getJoinableStrandPhotos(user.id, user.last_location_point.x, user.last_location_point.y, strands, friendsIds)

		names = list()
		for photo in joinableStrandPhotos:
			names.append(photo.user.display_name)

		# Grab unique names
		names = set(names)
		
		if len(names) > 0:
			msg = " & ".join(names) + " took a photo near you! Take a photo to see it."

			# We want to see if the user has gotten this message before.  Also, we want to support
			#   new people showing up so if the message is longer than they got before, send.
			skipNotification = False
			if user.id in notificationsById:
				for notification in notificationsById[user.id]:

					if notification.msg_type == msgType:
						if (len(notification.msg) == len(msg) or 
							notification.msg == ""):
						
							skipNotification = True
					if notification.msg_type == constants.NOTIFICATIONS_NEW_PHOTO_ID:
						skipNotification = True

			if not skipNotification:
				logger.debug("Sending %s to %s" % (msg, user.id))
				logEntry = notifications_util.sendNotification(user, msg, msgType, None)
				if logEntry:
					notificationLogsCache.append(logEntry)

	return notificationLogsCache
			
"""
	Send notifications for actions on photos.
	Right now, just for favoriting.  We grab all the actions where the user_notified_time isn't set,
	  so we don't use the notification logs right now.
"""	
def sendPhotoActionNotifications(now, waitTime):
	likeNotificationWaitSeconds = now - waitTime

	photoActions = PhotoAction.objects.select_related().filter(added__lte=likeNotificationWaitSeconds).filter(user_notified_time=None)
	usersToUpdateFeed = list()

	for photoAction in photoActions:
		if photoAction.action_type == "favorite":
			if photoAction.user_id != photoAction.photo.user_id:
				msg = "%s just liked your photo!" % (photoAction.user.display_name)
				msgType = constants.NOTIFICATIONS_PHOTO_FAVORITED_ID
				# Make name small since we only have 256 characters
				customPayload = {'pid': photoAction.photo_id}

				logger.info("Sending %s to %s" % (msg, photoAction.photo.user))
				notifications_util.sendNotification(photoAction.photo.user, msg, msgType, customPayload)

			photoAction.user_notified_time = datetime.datetime.utcnow()
			photoAction.save()
		usersToUpdateFeed.append(photoAction.photo.user)

	# Tell all the users who just had photos liked to refresh their feeds
	usersToUpdateFeed = set(usersToUpdateFeed)
	for user in usersToUpdateFeed:
		logger.debug("Sending refreshFeed msg to user %s" % (user.id))
		notifications_util.sendRefreshFeed(user)

"""
	If we haven't gotten a gps coordinate from them in the last hour, then send a ping
"""
def sendGpsNotification(now, gpsRefreshTime, notificationLogsCache):
	msgType = constants.NOTIFICATIONS_FETCH_GPS_ID
	frequencyOfGpsUpdatesCutoff = now - gpsRefreshTime
	
	notificationsById = notifications_util.getNotificationsForTypeById(notificationLogsCache, msgType, frequencyOfGpsUpdatesCutoff)
	usersWithOldGpsData = User.objects.filter(product_id=1).filter(last_location_timestamp__lt=frequencyOfGpsUpdatesCutoff)

	for user in usersWithOldGpsData:
		if user.id not in notificationsById:
			logger.debug("Pinging user %s to update their gps" % (user.id))
			logEntry = notifications_util.sendNotification(user, "", msgType, dict())
			if logEntry:
				notificationLogsCache.append(logEntry)
				
	return notificationLogsCache

"""
	Raw firestarter kicks off when a user is simply nearby other users (no photos taken.)
	Very infrequent right now
"""
def sendRawFirestarter(now, gpsUpdatedWithin, notifiedWithin, distanceWithinMeters, notificationLogsCache):
	msgType = constants.NOTIFICATIONS_RAW_FIRESTARTER_ID
	
	gpsUpdatedCutoff = now - gpsUpdatedWithin
	users = User.objects.filter(product_id=1).filter(last_location_timestamp__gt=gpsUpdatedCutoff)

	notifiedCutoff = now - notifiedWithin
	notificationsById = notifications_util.getNotificationsForTypeByIds(notificationLogsCache, constants.NOTIFICATIONS_ANY, notifiedCutoff)

	for user in users:
		nearbyUsers = geo_util.getNearbyUsers(user.last_location_point.x, user.last_location_point.y, users, filterUserId=user.id, accuracyWithin = distanceWithinMeters)

		numNearbyUsers = len(nearbyUsers)
		if numNearbyUsers > 0 and user.id not in notificationsById:
			if numNearbyUsers == 1:
				msg = "You have a friend on Strand nearby. Take a photo to share with them!"
			else:
				msg = "You have %s friends on Strand nearby. Take a photo to share with them!" % (numNearbyUsers)
				
			logger.debug("Sending raw firestarter msg to user %s " % (user.id))
			logEntry = notifications_util.sendNotification(user, msg, msgType, dict())
			if logEntry:
				notificationLogsCache.append(logEntry)
				
	return notificationLogsCache
"""
	Photo firestarter kicks off when a user has taken a photo recently
"""
def sendPhotoFirestarter(now, photoTakenWithin, gpsUpdatedWithin, notifiedWithin, accuracyWithinMeters, notificationLogsCache):
	msgType = constants.NOTIFICATIONS_PHOTO_FIRESTARTER_ID
	
	gpsUpdatedCutoff = now - gpsUpdatedWithin
	users = User.objects.filter(product_id=1).filter(last_location_timestamp__gt=gpsUpdatedCutoff)

	notifiedCutoff = now - notifiedWithin
	notificationsById = notifications_util.getNotificationsForTypeByIds(notificationLogsCache, constants.NOTIFICATIONS_ANY, notifiedCutoff)

	photoTakenCutoff = now - photoTakenWithin

	for user in users:
		nearbyUsers = geo_util.getNearbyUsers(user.last_location_point.x, user.last_location_point.y, users, filterUserId=user.id, accuracyWithin = accuracyWithinMeters)

		numNearbyUsers = len(nearbyUsers)

		# Check to see if they took a photo recently and have nearby users
		# Also make sure we haven't sent them either a raw firestarter or a photo one recently
		if (numNearbyUsers > 0 and
		  user.last_photo_timestamp and 
		  user.last_photo_timestamp.replace(tzinfo=pytz.utc) > photoTakenCutoff and 
		  user.id not in notificationsById):
			if numNearbyUsers == 1:
				msg = "You have a friend on Strand nearby. Take a photo to share with them!"
			else:
				msg = "You have %s friends on Strand nearby. Take a photo to share with them!" % (numNearbyUsers)
				
			logger.debug("Sending photo firestarter msg to user %s " % (user.id))
			logEntry = notifications_util.sendNotification(user, msg, msgType, dict())
			if logEntry:
				notificationLogsCache.append(logEntry)
			
	return notificationLogsCache

def main(argv):
	joinStrandWithin = datetime.timedelta(minutes=30)
	joinStrandGpsUpdatedWithin = datetime.timedelta(hours=8)
	waitTimeForPhotoAction = datetime.timedelta(seconds=10)
	gpsRefreshTime = datetime.timedelta(hours=3)

	rawFirestarterGpsUpdatedWithin = datetime.timedelta(hours=3)
	rawFirestarterNotifiedWithin = datetime.timedelta(days=7)
	rawFirestarterDistanceWithinMeters = 100 # meters

	photosFirestarterGpsUpdatedWithin = datetime.timedelta(hours=3)
	photosFirestarterNotifiedWithin = datetime.timedelta(days=3)
	photosFirestarterAccuracyWithinMeters = 100 # meters
	photosFirestarterPhotoTakenWithin = datetime.timedelta(minutes=30)

	# Want it to be the longest time we could want to grab cache
	notificationLogsWithin = datetime.timedelta(days=7)
	
	logger.info("Starting... ")
	while True:
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		# Grap notification logs for use in other methods
		notificationLogsCutoff = now - notificationLogsWithin

		notificationLogsCache = list()
		# Join Strand
		notificationLogsCache.extend(notifications_util.getNotificationLogsForType(now - joinStrandWithin, constants.NOTIFICATIONS_JOIN_STRAND_ID))
		# Gps
		notificationLogsCache.extend(notifications_util.getNotificationLogsForType(now - gpsRefreshTime, constants.NOTIFICATIONS_FETCH_GPS_ID))
		# Photo firestarter
		notificationLogsCache.extend(notifications_util.getNotificationLogsForType(now - photosFirestarterGpsUpdatedWithin, constants.NOTIFICATIONS_PHOTO_FIRESTARTER_ID))
		# Raw firestarter
		notificationLogsCache.extend(notifications_util.getNotificationLogsForType(now - rawFirestarterGpsUpdatedWithin, constants.NOTIFICATIONS_RAW_FIRESTARTER_ID))

		notificationLogsCache = sendJoinStrandNotification(now, joinStrandWithin, joinStrandGpsUpdatedWithin, notificationLogsCache)

		sendPhotoActionNotifications(now, waitTimeForPhotoAction)

		notificationLogsCache = sendGpsNotification(now, gpsRefreshTime, notificationLogsCache)

		notificationLogsCache = sendPhotoFirestarter(now, photosFirestarterPhotoTakenWithin, photosFirestarterGpsUpdatedWithin, photosFirestarterNotifiedWithin, photosFirestarterAccuracyWithinMeters, notificationLogsCache)

		notificationLogsCache = sendRawFirestarter(now, rawFirestarterGpsUpdatedWithin, rawFirestarterNotifiedWithin, rawFirestarterDistanceWithinMeters, notificationLogsCache)
				
		# Always sleep since we're doing a time based search above
		time.sleep(5)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
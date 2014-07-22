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
from common.models import Neighbor, NotificationLog, Photo, User, PhotoAction

import strand.notifications_util as notifications_util
import strand.geo_util as geo_util

logger = logging.getLogger(__name__)

def cleanName(str):
	return str.split(' ')[0].split("'")[0]

"""
	See if the given user has a photo neighbored with the given photo
"""
def hasNeighboredPhotoWithPhoto(user, photo, neighbors):
	if (user.id == photo.user_id):
		return False

	for neighbor in neighbors:
		if (photo.id == neighbor.photo_1_id and user.id == neighbor.user_2_id):
			return True
		elif (photo.id == neighbor.photo_2_id and user.id == neighbor.user_1_id):
			return True

	return False

"""
	Look through all recent photos from last 30 minutes and see if any users have a 
	  last_location_point near there...and haven't been notified recently about that user

	Check the photo we want to use to say if someone is nearby but we havent'
	neighbored with them yet (basically, they shouldn't know I'm there)
"""
def sendJoinStrandNotification(photos, users, neighbors, notificationLogs):
	msgType = constants.NOTIFICATIONS_JOIN_STRAND_ID

	notificationsById = notifications_util.getNotificationsForTypeById(notificationLogs, msgType)

	for user in users:
		nearbyPhotosData = geo_util.getNearbyPhotos(datetime.datetime.utcnow().replace(tzinfo=pytz.utc), user.last_location_point.x, user.last_location_point.y, photos, filterUserId=user.id)
		names = list()

		for nearbyPhotoData in nearbyPhotosData:
			(photo, timeDistance, geoDistance) = nearbyPhotoData

			# If we found a photo that has been neighbored and it isn't neighbored with
			#   the current user, then lets tell them to join up!
			# Otherwise, we want to skip it since we want to sent the new photo notification
			if photo.neighbored_time and not hasNeighboredPhotoWithPhoto(user, photo, neighbors):
				names.append(cleanName(photo.user.display_name))

		# Grab unique names
		names = set(names)
		
		if len(names) > 0:
			msg = " & ".join(names) + " took a photo near you! Take a photo to see it."

			# We want to see if the user has gotten this message before.  Also, we want to support
			#   new people showing up so if the message is longer than they got before, send.
			sentMessageBefore = False
			if user.id in notificationsById:
				for notification in notificationsById[user.id]:
					finalMsg = notifications_util.getMessageWithCustomPayload(msg, customPayload)
					if notification.msg == finalMsg:
						sentMessageBefore = True

			if not sentMessageBefore:
				logger.debug("Sending %s to %s" % (msg, user.id))
				notifications_util.sendNotification(user, msg, msgType, None)
				
def sendPhotoActionNotifications(photoActions):
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


def main(argv):
	maxFilesAtTime = 100

	timeWithSeconds = 30 * 60 # 30 minutes
	
	logger.info("Starting... ")
	while True:
		newPhotosStartTime = datetime.datetime.utcnow()-datetime.timedelta(seconds=timeWithSeconds)
		neighbors = Neighbor.objects.select_related().filter(Q(photo_1__time_taken__gt=newPhotosStartTime) | Q(photo_2__time_taken__gt=newPhotosStartTime)).order_by('photo_1')
		
		# Grap notification logs from last hour.  If a user isn't in here, then they weren't notified
		notificationLogs = notifications_util.getNotificationLogs(timeWithinSec=timeWithSeconds)

		# 30 minute cut off for join strand messages
		joinStrandStartTime = datetime.datetime.utcnow()-datetime.timedelta(seconds=timeWithSeconds)
		frequencyOfGpsUpdates = datetime.datetime.utcnow()-datetime.timedelta(hours=8)
		photos = Photo.objects.select_related().filter(time_taken__gt=joinStrandStartTime).filter(user__product_id=1)
		users = User.objects.filter(product_id=1).filter(last_location_timestamp__gt=frequencyOfGpsUpdates)

		sendJoinStrandNotification(photos, users, neighbors, notificationLogs)

		likeNotificationWaitSeconds = datetime.datetime.utcnow()-datetime.timedelta(seconds=10)

		photoActions = PhotoAction.objects.select_related().filter(added__lte=likeNotificationWaitSeconds).filter(user_notified_time=None)

		sendPhotoActionNotifications(photoActions)

		# Always sleep since we're doing a time based search above
		time.sleep(5)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.db.models import Count
from django.db.models import Q

from peanut import settings
from common.models import Neighbor, NotificationLog, Photo, User

import strand.notifications_util as notifications_util
import strand.geo_util as geo_util

logger = logging.getLogger(__name__)

def cleanName(str):
	return str.split(' ')[0].split("'")[0]

def getLastNotificationTimesForType(notificationLogs, msgType):
	lastNotificationTimes = dict()
	# create a dictionary per user on last notification time of NewPhoto notifications
	for notificationLog in notificationLogs:
		if notificationLog.msg_type == msgType:
			if notificationLog.user_id in lastNotificationTimes:
				if (lastNotificationTimes[notificationLog.user_id] < notificationLog.added):
					lastNotificationTimes[notificationLog.user_id] = notificationLog.added
			else:
				lastNotificationTimes[notificationLog.user_id] = notificationLog.added
	return lastNotificationTimes
"""
	Get all rows from Neighbor table in last 30 seconds
	Get all rows from NotificationLog table in last 60 seconds
	(can get this of second query by storing last notification time in the user table)
	create dictionary per user on last notification time
	for each row in neighbor table:
		for each user 
			look up the last notification time
			if notification_time > 1 hr, 
				if they should get a notification (they have the older photo in the neighbor row)
					send notification
"""
def sendNewPhotosNotification(neighbors, notificationLogs):
	msgType = settings.NOTIFICATIONS_NEW_PHOTO_ID

	if (len(neighbors) > 0):
		lastNotificationTimes = getLastNotificationTimesForType(notificationLogs, msgType)
		for neighbor in neighbors:
			if (neighbor.user_1.id not in lastNotificationTimes and 
				neighbor.photo_1.time_taken < neighbor.photo_2.time_taken):
					msg = cleanName(neighbor.user_2.first_name) + " added new photos!"
					logger.debug("Sending message '%s' to user %s" % (msg, neighbor.user_1_id))						
					notifications_util.sendNotification(neighbor.user_1, msg, msgType)
					lastNotificationTimes[neighbor.user_1_id] = datetime.datetime.utcnow()
			if (neighbor.user_2.id not in lastNotificationTimes and 
				neighbor.photo_2.time_taken < neighbor.photo_1.time_taken):
					msg = cleanName(neighbor.user_1.first_name) + " added new photos!"
					notifications_util.sendNotification(neighbor.user_2, msg, msgType)
					logger.debug("Sending message '%s' to user %s" % (msg, neighbor.user_2_id))
					lastNotificationTimes[neighbor.user_2_id] = datetime.datetime.utcnow()

"""
	Look through all recent photos from last 30 minutes and see if any users have a 
	  last_location_point near there...and haven't been notified recently

"""
def sendJoinStrandNotification(photos, users, notificationLogs):
	msgType = settings.IOS_NOTIFICATIONS_PROD_APNS_ID

	lastNotificationTimes = getLastNotificationTimesForType(notificationLogs, msgType)

	nonNotifiedUsers = filter(lambda x: x.id not in lastNotificationTimes, users)

	print "using users"
	print nonNotifiedUsers
	
	print "user photos"
	print photos
	
	for user in nonNotifiedUsers:
		nearbyPhotos = geo_util.getNearbyPhotos(datetime.datetime.utcnow().replace(tzinfo=pytz.utc), user.last_location_point.x, user.last_location_point.y, photos, filterUserId=user.id)
		if len(nearbyPhotos) > 0:
			(photo, timeDistance, geoDistance) = nearbyPhotos[0]
			name = cleanName(photo.user.first_name)
			msg = name + " took a photo near you!"

			print "Sending %s to %s" % (msg, user.first_name)
			notifications_util.sendNotification(user, msg, msgType)


def main(argv):
	maxFilesAtTime = 100
	
	logger.info("Starting... ")
	while True:
		newPhotosStartTime = datetime.datetime.utcnow()-datetime.timedelta(seconds=30)
		neighbors = Neighbor.objects.select_related().filter(Q(photo_1__time_taken__gt=newPhotosStartTime) | Q(photo_2__time_taken__gt=newPhotosStartTime)).order_by('photo_1')
		
		notificationLogs = NotificationLog.objects.select_related().filter(added__gt=datetime.datetime.utcnow()-datetime.timedelta(minutes=60))
		
		sendNewPhotosNotification(neighbors, notificationLogs)
		
		joinStrandStartTime = datetime.datetime.utcnow()-datetime.timedelta(minutes=30)
		photos = Photo.objects.select_related().filter(time_taken__gt=joinStrandStartTime).filter(user__product_id=1)
		users = User.objects.filter(product_id=1).filter(last_location_timestamp__gt=joinStrandStartTime)

		sendJoinStrandNotification(photos, users, notificationLogs)

		# Always sleep since we're doing a time based search above
		time.sleep(5)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
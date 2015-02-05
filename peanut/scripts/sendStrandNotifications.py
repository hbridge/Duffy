#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging
from threading import Thread

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.db.models import Count
from django.db.models import Q
from django import db

from peanut.settings import constants
from common.models import ShareInstance, User, LocationRecord, NotificationLog

from common import api_util

from strand import notifications_util, strands_util

logger = logging.getLogger(__name__)

def sendNewPhotoNotifications(shareInstance):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	logger.debug("in sendNewPhotoNotifications for share instance id %s" % shareInstance.id)
	location = strands_util.getBestLocation(shareInstance.photo)
	prettyDate = api_util.prettyDate(shareInstance.photo.time_taken)

	if now - shareInstance.photo.time_taken < datetime.timedelta(days=3):
		msg = "%s sent you a photo from %s" % (shareInstance.user.display_name, prettyDate)
	elif location:
		msg = "%s sent you a photo from %s" % (shareInstance.user.display_name, location)
	else:
		msg = "%s sent you a photo" % (shareInstance.user.display_name)
		
	doNotification = True

	if not shareInstance.photo.full_filename:
		return False

	for user in shareInstance.users.all():
		if user.id != shareInstance.user.id:
			logger.debug("going to send %s to user id %s" % (msg, user.id))
			customPayload = {'share_instance_id': shareInstance.id, 'id': shareInstance.photo.id}
			notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_NEW_PHOTO_ID, customPayload)

	# Kickoff separate notification for badging
	userIds = User.getIds(list(shareInstance.users.all()))
	Thread(target=notifications_util.threadedSendNotifications, args=(userIds,)).start()
	
	return True

def sendNewPhotoNotificationBatch(user, siList):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	logger.debug("in sendNewPhotoNotificationsBatch for user id %s" % user.id)

	if len(siList) == 1:
		msg = "You have %s new photo from %s" % (len(siList), siListToUserPhrase(siList))		
	else:
		msg = "You have %s new photos from %s" % (len(siList), siListToUserPhrase(siList))

	logger.info("going to send '%s' to user id %s" %(msg, user.id))
	customPayload = {'share_instance_id': siList[0].id, 'id': siList[0].photo.id}
	notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_NEW_PHOTO_ID, customPayload)

	# Kickoff separate notification for badging
	Thread(target=notifications_util.threadedSendNotifications, args=([user.id],)).start()	


def siListToUserPhrase(siList):
	userNames = set()
	
	for si in siList:
		userNames.add(si.user.display_name.split(' ', 1)[0])

	userPhrase = ""
	userNames = list(userNames)
	if len(userNames) == 1:
		userPhrase = userNames[0]
	elif len(userNames) == 2:
		userPhrase = userNames[0] + " and " + userNames[1]
	elif len(userNames) > 2:
		userPhrase = ', '.join(userNames[:-1]) + ', and ' + userNames[-1]
	
	return userPhrase

def main(argv):
	logger.info("Starting... ")
	notificationTimedelta = datetime.timedelta(seconds=300)
	recencyTimedelta = datetime.timedelta(seconds=constants.NOTIFICATIONS_NEW_PHOTO_WAIT_INTERVAL_SECS)

	locationSmallTimedelta = datetime.timedelta(hours=3)
	locationBigTimedelta = datetime.timedelta(days=3)
	
	while True:
		db.reset_queries()
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		notificationsSent = list()

		############################################
		### Notifications for new shareInstances ###
		############################################

		# get all pending shareInstances that users haven't been notified about 
		shareInstancesPending = ShareInstance.objects.filter(notification_sent__isnull=True).filter(added__gt=now-notificationTimedelta).filter(photo__full_filename__isnull=False)

		# Process pending shareInstances
		if len(shareInstancesPending) > 0:
			shareInstancesSent = ShareInstance.objects.exclude(notification_sent__isnull=True).filter(added__gt=now-recencyTimedelta)
			logger.debug("shareInstancesSent found: %s"%(len(shareInstancesSent)))
			usersSentNotsRecently = [si.user.id for si in shareInstancesSent]
			if len(usersSentNotsRecently) > 0:
				logger.debug("Users who sent a notification recently: %s"%(str(usersSentNotsRecently)))

			siByUser = dict()

			for si in shareInstancesPending:
				if si.user.id in usersSentNotsRecently:
					# skip if this user has sent a shareInstance (that we notified someone of) recently
					logger.info("skipping userId %s"%(si.user.id))
					continue
				else:
					notificationsSent.append(si)
					si.notification_sent = now
					for user in si.users.all():
						if user != si.user:
							if user in siByUser:
								siByUser[user].append(si)
							else:
								siByUser[user] = [si]

			for user, siList in siByUser.items():
				sendNewPhotoNotificationBatch(user, siList)

			if len(notificationsSent) > 0:
				ShareInstance.bulkUpdate(notificationsSent, ['notification_sent'])

		############################################
		### Notifications for updating location  ###
		############################################

		# get the list of users who have given us a past location and ping them
		usersInLocTable = LocationRecord.objects.filter(added__gt=now-locationBigTimedelta).values('user').distinct()
		userIds = [entry['user'] for entry in usersInLocTable]
		usersRecentlyInLocTable = LocationRecord.objects.filter(added__gt=now-locationSmallTimedelta).values('user').distinct()

		# Remove any userIds that have sent location in last 3 hours
		for entry in usersRecentlyInLocTable:
			if entry['user'] in userIds:
				userIds.remove(entry['user'])

		# Check to make sure that we haven't sent them a location ping in last 3 hours already
		recentlyPingedUsers = NotificationLog.objects.filter(added__gt=now-locationSmallTimedelta).filter(msg_type=constants.NOTIFICATIONS_FETCH_GPS_ID).values('user').distinct()

		for entry in recentlyPingedUsers:
			if entry['user'] in userIds:
				userIds.remove(entry['user']) 

		if len(userIds) > 0: #location ping
			logger.info("Found users to ping for 3 hour check: %s"%(userIds))
			users = User.objects.filter(id__in=userIds)
			for user in users:
				logger.debug("going to send a Fetch_GPS_ID to user id %s" % (user.id))
				customPayload = {}
				notifications_util.sendNotification(user, '', constants.NOTIFICATIONS_FETCH_GPS_ID, customPayload)
		
		time.sleep(1)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
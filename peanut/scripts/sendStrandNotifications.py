#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.db.models import Count
from django.db.models import Q

from peanut.settings import constants
from common.models import ShareInstance

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
	
	return True

def sendNewPhotoNotificationBatch(user, siList):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	logger.debug("in sendNewPhotoNotificationsBatch for user id %s" % user.id)

	msg = "You have %s new photos from %s in Swap" % (len(siList), siListToUserPhrase(siList))

	logger.info("going to send '%s' to user id %s" %(msg, user.id))
	logger.debug("going to send %s to user id %s" % (msg, user.id))
	customPayload = {'share_instance_id': siList[0].id, 'id': siList[0].photo.id}
	notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_NEW_PHOTO_ID, customPayload)


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
	recencyTimedelta = datetime.timedelta(seconds=30)
	
	while True:
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		notificationsSent = list()

		shareInstancesSent = ShareInstance.objects.filter(notification_sent__isnull=False).filter(added__gt=now-recencyTimedelta)
		shareInstancesPending = ShareInstance.objects.filter(notification_sent__isnull=True).filter(added__gt=now-notificationTimedelta).filter(photo__full_filename__isnull=False)

		usersSentNotsRecently = [si.user.id for si in shareInstancesSent]

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
		else:
			time.sleep(1)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
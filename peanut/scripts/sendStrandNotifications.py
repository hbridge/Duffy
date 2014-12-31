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

def main(argv):
	logger.info("Starting... ")
	notificationTimedelta = datetime.timedelta(seconds=300)
	
	while True:
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		notificationsSent = list()

		shareInstances = ShareInstance.objects.filter(notification_sent__isnull=True).filter(added__gt=now-notificationTimedelta)

		for shareInstance in shareInstances:
			if sendNewPhotoNotifications(shareInstance):
				shareInstance.notification_sent = now
				notificationsSent.append(shareInstance)

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
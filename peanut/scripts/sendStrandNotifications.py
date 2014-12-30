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
from common.models import Action, StrandInvite

from common import api_util

from strand import notifications_util, geo_util, strands_util, friends_util

logger = logging.getLogger(__name__)

def sendNewPhotoNotifications(action):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	logger.debug("in sendNewPhotoNotifications for action id %s" % action.id)
	location = strands_util.getBestLocation(action.photo)
	prettyDate = api_util.prettyDate(action.photo.time_taken)

	if now - action.photo.time_taken < datetime.timedelta(days=3):
		msg = "%s sent you a photo from %s" % (action.user.display_name, prettyDate)
	elif location:
		msg = "%s sent you a photo from %s" % (action.user.display_name, location)
	else:
		msg = "%s sent you a photo" % (action.user.display_name)
		
	doNotification = True

	if not action.photo.full_filename:
		doNotification = False

	if doNotification:
		for user in action.share_instance.users.all():
			if user.id != action.user.id:
				logger.debug("going to send %s to user id %s" % (msg, user.id))
				customPayload = {'share_instance_id': action.share_instance.id, 'id': action.photo.id}

				notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_NEW_PHOTO_ID, customPayload)
		
		return True
	return False

def main(argv):
	logger.info("Starting... ")
	notificationTimedelta = datetime.timedelta(seconds=300)
	
	while True:
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		inviteNotificationsSent = list()
		actionNotificationsSent = list()

		actions = Action.objects.filter(notification_sent__isnull=True).filter(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED).filter(added__gt=now-notificationTimedelta)

		for action in actions:
			if (action.user.id == action.photo.user.id): #check to make sure that photo is owned by the same person who evaluated it
				if sendNewPhotoNotifications(action):
					action.notification_sent = now
					actionNotificationsSent.append(action)

		if len(actionNotificationsSent) > 0:
			Action.bulkUpdate(actionNotificationsSent, ['notification_sent'])
			
		if len(actionNotificationsSent) == 0:
			time.sleep(1)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
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

def sendNewPhotoActionNotifications(action):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	logger.debug("in sendNewPhotoActionNotifications for strand id %s" % action.strand.id)
	location = strands_util.getLocationForStrand(action.strand)
	prettyDate = api_util.prettyDate(action.strand.first_photo_time)

	count = action.photos.count()
	if count == 0:
		# Just say we sent it when we really didn't
		return True

	elif count == 1:
		if now - action.strand.first_photo_time < datetime.timedelta(days=3):
			msg = "%s sent you a photo from %s" % (action.user.display_name, prettyDate)			
			#msg = "%s sent you a photo from %s" % (action.user.display_name, strands_util.getLocationForStrand(action.strand))
		elif location:
			msg = "%s sent you a photo from %s" % (action.user.display_name, location)
		else:
			msg = "%s sent you a photo" % (action.user.display_name)

	else: #count > 1
		if now - action.strand.first_photo_time < datetime.timedelta(days=3):
			msg = "%s sent you photos from %s" % (action.user.display_name, prettyDate)
		elif location:
			msg = "%s sent you photos from %s" % (action.user.display_name, location)
		else:
			msg = "%s sent you a photo" % (action.user.display_name)

		
	doNotification = True

	for photo in action.photos.all():
		if not photo.full_filename:
			doNotification = False

	if doNotification:
		for user in action.strand.users.all():
			if user.id != action.user.id:
				logger.debug("going to send %s to user id %s" % (msg, user.id))
				customPayload = {'strand_id': action.strand.id, 'id': action.strand.photos.all()[0].id}

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

		actions = Action.objects.filter(notification_sent__isnull=True).filter(Q(action_type=constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND) | Q(action_type=constants.ACTION_TYPE_CREATE_STRAND)).filter(added__gt=now-notificationTimedelta)

		for action in actions:
			if sendNewPhotoActionNotifications(action):
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
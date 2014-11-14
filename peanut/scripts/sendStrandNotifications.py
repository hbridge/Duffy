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

from strand import notifications_util, geo_util, strands_util, friends_util

logger = logging.getLogger(__name__)



def sendInviteNotification(strandInvite):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	logger.debug("in sendInviteNotification for invite id %s" % strandInvite.id)
	msg = "%s wants to swap photos from %s" % (strandInvite.user.display_name, strandInvite.strand.photos.all()[0].location_city)
	
	doNotification = True

	if not strandInvite.invited_user:
		doNotification = False

	for photo in strandInvite.strand.photos.all():
		if not photo.full_filename:
			doNotification = False

	if doNotification:
		logger.debug("going to send %s to user id %s" % (msg, strandInvite.invited_user.id))
		customPayload = {'id': strandInvite.id}
		notifications_util.sendNotification(strandInvite.invited_user, msg, constants.NOTIFICATIONS_INVITED_TO_STRAND, customPayload)
		return True
	return False

def sendJoinActionNotifications(action):
	count = action.photos.count()
	if count == 0:
		# Just say we sent it when we really didn't
		return True
	elif count == 1:
		msg = "%s added 1 photo from %s" % (action.user.display_name, action.strand.photos.all()[0].location_city)
	else:
		msg = "%s added %s photos from %s" % (action.user.display_name, action.photos.count(), action.strand.photos.all()[0].location_city)
		
	doNotification = True

	for photo in action.photos.all():
		if not photo.full_filename:
			doNotification = False

	if doNotification:
		for user in action.strand.users.all():
			if user.id != action.user.id:
				logger.debug("going to send %s to user id %s" % (msg, user.id))
				customPayload = {'id': action.strand.id}
				notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_ACCEPTED_INVITE, customPayload)
		
		return True
	return False

def main(argv):
	logger.info("Starting... ")
	notificationTimedelta = datetime.timedelta(seconds=300)
	
	while True:
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		inviteNotificationsSent = list()
		actionNotificationsSent = list()

		actions = Action.objects.filter(notification_sent__isnull=True).filter(action_type=constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND).filter(added__gt=now-notificationTimedelta)

		for action in actions:
			if sendJoinActionNotifications(action):
				action.notification_sent = now
				actionNotificationsSent.append(action)

		invites = StrandInvite.objects.select_related().filter(notification_sent__isnull=True).filter(added__gt=now-notificationTimedelta).filter(skip=False)

		for invite in invites:
			if sendInviteNotification(invite):
				invite.notification_sent = now
				inviteNotificationsSent.append(invite)

		if len(inviteNotificationsSent) > 0:
			StrandInvite.bulkUpdate(inviteNotificationsSent, ['notification_sent'])

		if len(actionNotificationsSent) > 0:
			Action.bulkUpdate(actionNotificationsSent, ['notification_sent'])
			
		if invites.count() == 0:
			time.sleep(1)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
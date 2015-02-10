from __future__ import absolute_import
import sys, os
import time, datetime
import logging

from django.dispatch import receiver
from django.db.models.signals import post_save

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from common.models import User, ContactEntry, FriendConnection, Action, ShareInstance

from strand import notifications_util

from peanut.settings import constants
from peanut.celery import app

from async import celery_helper

from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

@receiver(post_save, sender=Action)
def sendNotificationsUponActions(sender, **kwargs):
	action = kwargs.get('instance')

	users = list()

	if action.share_instance:
		users = list(action.share_instance.users.all())
		
	if action.user and action.user not in users:
		users.append(action.user)

	userIds = User.getIds(users)

	sendRefreshFeedToUserIds.delay(userIds)

def siListToUserPhrase(shareInstances):
	userNames = set()
	
	for shareInstance in shareInstances:
		userNames.add(shareInstance.user.display_name.split(' ', 1)[0])

	userPhrase = ""
	userNames = list(userNames)
	if len(userNames) == 1:
		userPhrase = userNames[0]
	elif len(userNames) == 2:
		userPhrase = userNames[0] + " and " + userNames[1]
	elif len(userNames) > 2:
		userPhrase = ', '.join(userNames[:-1]) + ', and ' + userNames[-1]
	
	return userPhrase

@app.task
def sendNewPhotoNotificationBatch(userId, shareInstanceIdList):
	user = User.objects.get(id=userId)
	shareInstances = ShareInstance.objects.filter(id__in=shareInstanceIdList)

	logger.debug("in sendNewPhotoNotificationsBatch for user id %s" % user.id)

	if len(shareInstances) == 1:
		msg = "You have %s new photo from %s" % (len(shareInstances), siListToUserPhrase(shareInstances))		
	else:
		msg = "You have %s new photos from %s" % (len(shareInstances), siListToUserPhrase(shareInstances))

	logger.info("going to send '%s' to user id %s" %(msg, user.id))
	customPayload = {'share_instance_id': shareInstances[0].id, 'id': shareInstances[0].photo_id}
	notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_NEW_PHOTO_ID, customPayload)

	# Kickoff separate notification for badging
	sendRefreshFeedToUserIds.delay([user.id])	


@app.task
def sendRefreshFeedToUserIds(userIds):
	notifications_util.threadedSendNotifications(userIds)
	return len(userIds)


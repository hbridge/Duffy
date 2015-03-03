from __future__ import absolute_import
import sys, os
import time, datetime
import logging
import pytz

from django.dispatch import receiver
from django.db.models.signals import post_save

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from common.models import User, ContactEntry, FriendConnection, Action, ShareInstance, NotificationLog
from common import api_util

from strand import notifications_util, users_util

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
def sendRequestPhotosNotification(actionId):
	action = Action.objects.prefetch_related('strand').get(id=actionId)
	privateStrand = action.strand
	name = users_util.getContactBasedFirstName(action.user, privateStrand.user)

	msg = "%s wants your photos from %s, his memory is fuzzy" % (name, api_util.prettyDate(privateStrand.first_photo_time).lower())		
	
	logger.info("going to send '%s' to user id %s" %(msg, privateStrand.user_id))
	customPayload = {'strand_id': privateStrand.id, 'id': privateStrand.photos.all()[0].id}
	notifications_util.sendNotification(privateStrand.user, msg, constants.NOTIFICATIONS_PHOTOS_REQUESTED, customPayload)

	# Kickoff separate notification for badging
	sendRefreshFeedToUserIds.delay([privateStrand.user_id])


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
def sendAddFriendNotificationBatch(actionIdList):
	actions = Action.objects.prefetch_related('user', 'target_user').filter(id__in=actionIdList)
	userIdsToRefresh = set()
	logger.debug("in sendAddFriendNotificationBatch for actionIds: %s"%actionIdList)

	for action in actions:
		msg = action.user.display_name.split(' ', 1)[0] + ' ' + action.text
		logger.info("going to send '%s' to user id %s" %(msg, action.target_user_id))
		customPayload = {'id': action.user_id}
		notifications_util.sendNotification(action.target_user, msg, constants.NOTIFICATIONS_ADD_FRIEND, customPayload)
		userIdsToRefresh.add(action.target_user_id)

	# Kickoff separate notification for badging
	sendRefreshFeedToUserIds.delay(userIdsToRefresh)	


@app.task
def sendRefreshFeedToUserIds(userIds):
	notifications_util.threadedSendNotifications(userIds)
	return len(userIds)



def shareInstancesToPhrases(siList):
	photoCount = len(siList)

	photoPhrase = ""
	if (photoCount == 1):
		photoPhrase = "a photo"
	elif (photoCount > 1):
		photoPhrase = "%s photos" % (photoCount)

	userNames = set()

	for si in siList:
		userNames.add(si.user.display_name.split(' ', 1)[0])

	userNames = list(userNames)
	if len(userNames) == 0:
		userPhrase = ''
	if len(userNames) == 1:
		userPhrase = 'from ' + userNames[0]
	elif len(userNames) == 2:
		userPhrase = "from " + userNames[0] + " and " + userNames[1]
	elif len(userNames) > 2:
		userPhrase = "from " + ', '.join(userNames[:-1]) + ', and ' + userNames[-1]

	return photoPhrase, userPhrase


@app.task
def sendUnactivatedAccountFS():
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	gracePeriodTimedeltaDays = datetime.timedelta(days=constants.NOTIFICATIONS_ACTIVATE_ACCOUNT_FS_GRACE_PERIOD_DAYS)
	intervalTimedeltaDays = datetime.timedelta(days=constants.NOTIFICATIONS_ACTIVATE_ACCOUNT_FS_INTERVAL_DAYS)

	# generate a list of non-authed users
	nonAuthedUsers = list(User.objects.filter(product_id=2).filter(has_sms_authed=False).filter(added__lt=now-gracePeriodTimedeltaDays).filter(added__gt=now-intervalTimedeltaDays))
	
	logger.info("Non-authed users: %s"% nonAuthedUsers)

	# generate a list of pinged users (as a dict - because of distinct() clause) in the interval for this notification
	recentlyPingedUsers = NotificationLog.objects.filter(added__gt=now-intervalTimedeltaDays).filter(msg_type=constants.NOTIFICATIONS_ACTIVATE_ACCOUNT_FS).filter(user__in=nonAuthedUsers).values('user').distinct()

	logger.info("recentlyPingedUsers %s"% recentlyPingedUsers)

	recentUserIds = [entry['user'] for entry in recentlyPingedUsers]
	
	# remove those users
	usersToNotify = [user for user in nonAuthedUsers if not (user.id in recentUserIds)]

	logger.info("usersToNotify %s"% usersToNotify)

	# remove those users who don't have any photos to see in the app
	shareInstances = ShareInstance.objects.filter(users__in=usersToNotify)

	usersWithPhotos = set()
	shareInstancesByUserId = dict()

	for si in shareInstances:
		for user in si.users.all():
			if user in usersToNotify:
				usersWithPhotos.add(user)
				if user.id in shareInstancesByUserId:
					shareInstancesByUserId[user.id].append(si)
				else:
					shareInstancesByUserId[user.id] = [si]

	logger.info("usersWithPhotos %s" % usersWithPhotos)

	msgCount = 0
	for user in list(usersWithPhotos):
		# generate msg
		photoPhrase, userPhrase = shareInstancesToPhrases(shareInstancesByUserId[user.id])
		msg = "You have " + photoPhrase + " " + userPhrase + " waiting for you."
		msgCount += 1

		# send msg
		logger.debug("going to send '%s' to user id %s" % (msg, user.id))
		customPayload = {}
		notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_ACTIVATE_ACCOUNT_FS, customPayload)

	return msgCount


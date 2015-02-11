from __future__ import absolute_import
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
from django.db.models import Q, F

from peanut.settings import constants
from common.models import Photo, NotificationLog, User, Strand

from strand import notifications_util, friends_util, swaps_util

from peanut.celery import app

from async import celery_helper
from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)



def sendSuggestionNotification(user, interestedUsersByStrandId, matchReasonsByStrandId, strands):
	photoCount = 0
	userNames = set()
	photosForNotification = list()

	for strand in strands:
		# TODO: add a check for right reason (location-user or location-strand)
		for intUser in interestedUsersByStrandId[strand.id]:
			userNames.add(intUser.display_name.split(' ', 1)[0])

		for photo in strand.photos.all():
			if not photo.notification_evaluated:
				photo.notification_evaluated = True
				photosForNotification.append(photo)

	if len(photosForNotification) > 0:
		photoPhrase, userPhrase = listsToPhrases(len(photosForNotification), userNames)

		msg = "Send your recent %s to %s in Swap"%(photoPhrase, userPhrase)

		logger.debug("going to send '%s' to user id %s" % (msg, user.id))
		customPayload = {'id': strands[0].id}
		notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_NEW_SUGGESTION, customPayload)

	return photosForNotification


def listsToPhrases(photoCount, userNames):
	if (photoCount == 0):
		return '',''
	elif (photoCount == 1):
		photoPhrase = "photo"
	elif (photoCount > 1):
		photoPhrase = "photos"

	if (len(userNames) > 0):
		userNames = list(userNames)
	else:
		userNames = list()

	if len(userNames) == 1:
		userPhrase = userNames[0]
	elif len(userNames) == 2:
		userPhrase = userNames[0] + " and " + userNames[1]
	elif len(userNames) > 2:
		userPhrase = userNames[0] + ", " + userNames[1] + " and %s others"%(len(userNames)-2)
	else:
		logger.error("No usernames found!")
		return None
	
	return (photoPhrase, userPhrase)


def processBatch(strandsToProcess):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	notificationTimedelta = datetime.timedelta(seconds=constants.NOTIFICATIONS_NEW_SUGGESTION_INTERVAL_SECS)

	strandsByUser = dict()
	userIds = set()
	for strand in strandsToProcess:
		if not strand.user in strandsByUser:
			strandsByUser[strand.user] = list()
		strandsByUser[strand.user].append(strand)
		userIds.add(strand.user_id)

	# get all the suggestions sent out in the last 60 sec and don't send to those users
	recentUsersNotified = NotificationLog.objects.filter(user_id__in=userIds).filter(msg_type=constants.NOTIFICATIONS_NEW_SUGGESTION).filter(result=constants.IOS_NOTIFICATIONS_RESULT_SENT).filter(added__gt=now-notificationTimedelta)

	photosToUpdate = list()
	count = 0

	for user, recentStrands in strandsByUser.items():
		fullFriends, forwardFriends, reverseFriends = friends_util.getFriends(user.id)
		interestedUsersByStrandId, matchReasonsByStrandId, strands = swaps_util.getInterestedUsersForStrands(user, recentStrands, True, fullFriends)

		if len(strands) > 0:
			# this will skip strands that already are notified on
			photosUpdated = sendSuggestionNotification(user, interestedUsersByStrandId, matchReasonsByStrandId, strands)
			photosToUpdate.extend(photosUpdated)
				
		if len(photosToUpdate) > 0:
			Photo.bulkUpdate(photosToUpdate, ['notification_evaluated'])
		count += len(photosToUpdate)

	return count

baseQuery = Strand.objects.prefetch_related('photos', 'user').filter(private=True)
numToProcess = 50


@app.task
def processIds(ids):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	photoTimedelta = datetime.timedelta(days=1)
	return celery_helper.processBatch(baseQuery.filter(id__in=ids).filter(first_photo_time__gt=now-photoTimedelta), numToProcess, processBatch)


@app.task
def processUserId(userId):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	photoTimedelta = datetime.timedelta(days=1)
	return celery_helper.processBatch(baseQuery.filter(user_id=userId).filter(first_photo_time__gt=now-photoTimedelta), numToProcess, processBatch)



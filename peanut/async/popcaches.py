from __future__ import absolute_import
import os, sys
import logging
import datetime
import pytz
import json
import time
from threading import Thread

from django.db.models import Q
from django.conf import settings
from django.db import connection

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django

django.setup()

from django import db

from strand import swaps_util, friends_util
from common.models import Strand, User, ApiCache

from common import stats_util, serializers, api_util
import strand.notifications_util as notifications_util

from peanut.settings import constants

from peanut.celery import app

from async import celery_helper
from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

def threadedSendNotifications(userIds):
	time.sleep(1)
	logging.basicConfig(filename='/var/log/duffy/stranding.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	logger = logging.getLogger(__name__)

	users = User.objects.filter(id__in=userIds)

	# Send update feed msg to folks who are involved in these photos
	notifications_util.sendRefreshFeedToUsers(users)


def threadedPerformFullPrivateStrands(userId):
	logger = get_task_logger(__name__)
	user = User.objects.get(id=userId)
	feedObjects = swaps_util.getFeedObjectsForPrivateStrands(user)

	try:
		apiCache = ApiCache.objects.get(user_id=user.id)
	except ApiCache.DoesNotExist:
		apiCache = ApiCache.objects.create(user=user)

	response = dict()
	response['objects'] = feedObjects
	apiCache.private_strands_data = json.dumps(response, cls=api_util.DuffyJsonEncoder)
	apiCache.private_strands_full_last_timestamp = datetime.datetime.utcnow()

	apiCache.save()

	logger.info("Finished full private strand refresh for user %s" % (userId))
	Thread(target=threadedSendNotifications, args=([userId],)).start()

def processBatch(strandsToProcess):
	# Group by user
	dirtyStrandsByUserId = dict()
	total = 0

	for strand in strandsToProcess:
		if strand.user_id not in dirtyStrandsByUserId:
			dirtyStrandsByUserId[strand.user_id] = list()
		dirtyStrandsByUserId[strand.user_id].append(strand)

	usersIdsToSendNotificationsTo = list()
	for userId, strandList in dirtyStrandsByUserId.iteritems():
		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			logger.error("Couldn't find user: %s" % userId)
			continue
						
		fullFriends, forwardFriends, reverseFriends = friends_util.getFriends(user.id)

		for strand in strandList:
			for photo in strand.photos.all():
				photo.user = user

		interestedUsersByStrandId, matchReasonsByStrandId, strands = swaps_util.getInterestedUsersForStrands(user, strandList, True, fullFriends)

		try:
			apiCache = ApiCache.objects.get(user_id=user.id)
		except ApiCache.DoesNotExist:
			apiCache = ApiCache.objects.create(user=user)

		responseObjectsById = dict()
		if apiCache.private_strands_data:
			responseObjects = json.loads(apiCache.private_strands_data)['objects']

			for responseObject in responseObjects:
				responseObjectsById[responseObject['id']] = responseObject

		strandsProcessed = list()
		strandsToDelete = list()
		for strand in strandList:
			# Stranding might not have added all the photos yet, so wait a bit
			if len(strand.photos.all()) == 0:
				logger.info("Skipped strand %s because of 0 photos" % (strand.id))

				if strand.added < datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(minutes=5):
					strandsToDelete.append(strand)
				continue
				
			strandObjectData = serializers.objectDataForPrivateStrand(user, strand, fullFriends, True, "", interestedUsersByStrandId, matchReasonsByStrandId, dict())
			if strandObjectData:
				responseObjectsById[strandObjectData['id']] = strandObjectData
				logger.info("Inserted strand %s for user %s" % (strandObjectData['id'], userId))
			else:
				if strand.id in responseObjectsById:
					del responseObjectsById[strand.id]
					logger.info("explicitly removed strand %s from cache for user %s" % (strand.id, userId))
				else:
					logger.info("Did not insert strand %s for user %s" % (strand.id, userId))

			strand.cache_dirty = False
			strandsProcessed.append(strand)

		for strand in strandsToDelete:
			logger.warning("Deleting strand %s because it had no photos and was created %s" % (strand.id, strand.added))
			strand.delete()
		responseObjects = responseObjectsById.values()
		responseObjects = sorted(responseObjects, key=lambda x: x['time_taken'], reverse=True)

		response = dict()
		response['objects'] = responseObjects
		apiCache.private_strands_data = json.dumps(response, cls=api_util.DuffyJsonEncoder)
		apiCache.private_strands_data_last_timestamp = datetime.datetime.utcnow()

		apiCache.save()

		Strand.bulkUpdate(strandsProcessed, ['cache_dirty'])
		
		if len(strandsProcessed) > 0:
			usersIdsToSendNotificationsTo.append(userId)
			
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		if (not apiCache.private_strands_full_last_timestamp or apiCache.private_strands_full_last_timestamp < now - datetime.timedelta(minutes=5)):
			processFull.delay(userId)
		total += len(strandsProcessed)

	Thread(target=threadedSendNotifications, args=(set(usersIdsToSendNotificationsTo),)).start()

	return total


baseQuery = Strand.objects.prefetch_related('photos').filter(user__isnull=False).filter(cache_dirty=True).filter(private=True).order_by('-first_photo_time')
numToProcess = 50

@app.task
def processAll():
	return celery_helper.processBatch(baseQuery, numToProcess, processBatch)

@app.task
def processFull(userId):
	startTime = datetime.datetime.utcnow()
	threadedPerformFullPrivateStrands(userId)
	endTime = datetime.datetime.utcnow()
	msTime = ((endTime-startTime).microseconds / 1000 + (endTime-startTime).seconds * 1000)
	return (userId, "%s ms" % msTime)
	
	

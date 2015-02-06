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
from common.models import Strand, User, ApiCache, ShareInstance, Action

from common import stats_util, serializers, api_util
import strand.notifications_util as notifications_util

from peanut.settings import constants

from peanut.celery import app

from async import celery_helper, notifications
from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)


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
	notifications.sendRefreshFeedToUserIds.delay([userId])

def processPrivateStrandsBatch(strandsToProcess):
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
				responseObjectsById[int(responseObject['id'])] = responseObject

		strandsProcessed = list()
		strandsToDelete = list()
		for strand in strandList:
			# Stranding might not have added all the photos yet, so wait a bit
			if len(strand.photos.all()) == 0:
				logger.info("Skipped strand %s because of 0 photos" % (strand.id))

				if strand.added < datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(minutes=5):
					strandsToDelete.append(strand)
				continue
				
			strandObjectData = serializers.objectDataForPrivateStrand(user,
																  strand,
																  fullFriends,
																  True, # includeNotEval
																  True, # includeFaces
																  True, # includeAll
																  "", # suggestionType
																  interestedUsersByStrandId, matchReasonsByStrandId, dict())

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
			processPrivateStrandFull.delay(userId)
		total += len(strandsProcessed)

	notifications.sendRefreshFeedToUserIds.delay(set(usersIdsToSendNotificationsTo))

	return total


privateStrandsBaseQuery = Strand.objects.prefetch_related('photos').filter(user__isnull=False).filter(cache_dirty=True).filter(private=True).order_by('-first_photo_time')
privateStrandsNumToProcess = 50

@app.task
def processPrivateStrandsAll():
	return celery_helper.processBatch(privateStrandsBaseQuery, privateStrandsNumToProcess, processPrivateStrandsBatch)

@app.task
def processPrivateStrandIds(strandIds):
	return celery_helper.processBatch(privateStrandsBaseQuery.filter(id__in=strandIds), privateStrandsNumToProcess, processPrivateStrandsBatch)

@app.task
def processPrivateStrandFull(userId):
	startTime = datetime.datetime.utcnow()
	threadedPerformFullPrivateStrands(userId)
	endTime = datetime.datetime.utcnow()
	msTime = ((endTime-startTime).microseconds / 1000 + (endTime-startTime).seconds * 1000)
	return (userId, "%s ms" % msTime)



###################################################################
#########################      Inbox       ########################
###################################################################


def processInboxBatch(shareInstancesToProcess):
	# Group by user
	dirtyShareInstancesByUserId = dict()
	total = 0

	for shareInstance in shareInstancesToProcess:
		for user in shareInstance.users.all():
			if user.id not in dirtyShareInstancesByUserId:
				dirtyShareInstancesByUserId[user.id] = list()
			dirtyShareInstancesByUserId[user.id].append(shareInstance)

	# Now grab all the actions for these ShareInstances (comments, evals, likes)
	shareInstanceIds = ShareInstance.getIds(shareInstancesToProcess)

	actions = Action.objects.filter(share_instance_id__in=shareInstanceIds)
	actionsByShareInstanceId = dict()
	
	for action in actions:
		if action.share_instance_id not in actionsByShareInstanceId:
			actionsByShareInstanceId[action.share_instance_id] = list()
		actionsByShareInstanceId[action.share_instance_id].append(action)

	usersIdsToSendNotificationsTo = list()
	shareInstancesProcessed = list()
	for userId, shareInstanceList in dirtyShareInstancesByUserId.iteritems():
		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			logger.error("Couldn't find user: %s" % userId)
			continue

		try:
			apiCache = ApiCache.objects.get(user_id=user.id)
		except ApiCache.DoesNotExist:
			apiCache = ApiCache.objects.create(user=user)

		# skip users who don't have any inbox data, require a full first
		if not apiCache.inbox_full_last_timestamp:
			continue

		responseObjectsById = dict()
		if apiCache.inbox_data:
			responseObjects = json.loads(apiCache.inbox_data)['objects']

			for responseObject in responseObjects:
				responseObjectsById[int(responseObject['share_instance'])] = responseObject


		for shareInstance in shareInstanceList:
			actions = list()
			if shareInstance.id in actionsByShareInstanceId:
				actions = actionsByShareInstanceId[shareInstance.id]

			objectData = serializers.objectDataForShareInstance(shareInstance, actions, user)

			if objectData:
				# suggestion_rank here for backwards compatibility, remove upon next mandatory updatae after Jan 2
				objectData['sort_rank'] = swaps_util.getSortRanking(user, shareInstance, actions)
				objectData['suggestion_rank'] = objectData['sort_rank']

				responseObjectsById[objectData['share_instance']] = objectData
				logger.info("Inserted share instance %s for user %s" % (objectData['share_instance'], userId))
			else:
				if shareInstance.id in responseObjectsById:
					del responseObjectsById[shareInstance.id]
					logger.info("explicitly removed strand %s from cache for user %s" % (strand.id, userId))
				else:
					logger.info("Did not insert strand %s for user %s" % (strand.id, userId))


		responseObjects = responseObjectsById.values()
		responseObjects = sorted(responseObjects, key=lambda x: x['sort_rank'])

		response = dict()
		response['objects'] = responseObjects
		apiCache.inbox_data = json.dumps(response, cls=api_util.DuffyJsonEncoder)
		apiCache.inbox_data_last_timestamp = datetime.datetime.utcnow()

		apiCache.save()

		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		if (not apiCache.inbox_full_last_timestamp or apiCache.inbox_full_last_timestamp < now - datetime.timedelta(minutes=5)):
			processInboxFull.delay(userId)

	for shareInstance in shareInstancesToProcess:
		shareInstance.cache_dirty = False

	ShareInstance.bulkUpdate(shareInstancesToProcess, ['cache_dirty'])

	notifications.sendRefreshFeedToUserIds.delay(dirtyShareInstancesByUserId.keys())

	return len(shareInstancesToProcess)

inboxBaseQuery = ShareInstance.objects.prefetch_related('photo', 'users', 'photo__user').filter(cache_dirty=True).order_by("-updated", "id")
inboxNumToProcess = 50


@app.task
def processInboxAll():
	return celery_helper.processBatch(inboxBaseQuery, inboxNumToProcess, processInboxBatch)

@app.task
def processInboxIds(shareInstanceIds):
	return celery_helper.processBatch(inboxBaseQuery.filter(id__in=shareInstanceIds), inboxNumToProcess, processInboxBatch)

@app.task
def processInboxFull(userId):
	startTime = datetime.datetime.utcnow()
	
	logger = get_task_logger(__name__)
	user = User.objects.get(id=userId)
	feedObjects = swaps_util.getFeedObjectsForInbox(user, None, None)

	try:
		apiCache = ApiCache.objects.get(user_id=user.id)
	except ApiCache.DoesNotExist:
		apiCache = ApiCache.objects.create(user=user)

	response = dict()
	response['objects'] = feedObjects
	apiCache.inbox_data = json.dumps(response, cls=api_util.DuffyJsonEncoder)
	apiCache.inbox_full_last_timestamp = datetime.datetime.utcnow()

	apiCache.save()

	logger.info("Finished full inbox refresh for user %s" % (userId))
	notifications.sendRefreshFeedToUserIds.delay([userId])

	endTime = datetime.datetime.utcnow()
	msTime = ((endTime-startTime).microseconds / 1000 + (endTime-startTime).seconds * 1000)
	return (userId, "%s ms" % msTime)


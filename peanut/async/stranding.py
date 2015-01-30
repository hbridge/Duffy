from __future__ import absolute_import
import sys, os
import time, datetime
import logging
import math
import pytz
from threading import Thread

from django.contrib.gis.geos import *
from django.contrib.gis.measure import D

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django import db
from django.db import IntegrityError
from django.db.models import Count, Q

from peanut.settings import constants
from common.models import Photo, Strand, User, LocationRecord, FriendConnection, NotificationLog

from strand import geo_util, friends_util, strands_util
import strand.notifications_util as notifications_util

from peanut.celery import app

from async import celery_helper
from async import popcaches, neighboring, suggestion_notifications

from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)


def dealWithDeadStrand(strand, strandsCache):
	logging.error("populateStrands tried to eval strand %s with 0 users", (strand.id))
	# remove from our cache and db
	strandsCache = filter(lambda a: a.id != strand.id, strandsCache)
	logger.debug("Deleted strand %s" % strand.id)
	strand.delete()

	return strandsCache


def threadedSendNotifications(userIds):
	logger = get_task_logger(__name__)
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)

	users = User.objects.filter(id__in=userIds)

	# Send update feed msg to folks who are involved in these photos
	notifications_util.sendRefreshFeedToUsers(users)

"""
	Takes in:
	photosAndStrandDict - Dictionary key being a photo and value the strandId
	usersByStrandId - Dictionary key being a strandId and value a list of users in the strand

"""
def sendNotifications(photoToStrandIdDict, usersByStrandId, timeWithinSecondsForNotification):
	msgType = constants.NOTIFICATIONS_SOCKET_REFRESH_FEED
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	notificationLogsCutoff = now - datetime.timedelta(seconds=timeWithinSecondsForNotification)
	
	# Grab logs from last 30 seconds (default) then grab the last time they were notified
	notificationLogs = notifications_util.getNotificationLogs(notificationLogsCutoff)
	notificationsById = notifications_util.getNotificationsForTypeById(notificationLogs, msgType)

	# This is a dict with the user as the key and a list of other users w photos as the value
	usersToNotifyAboutById = dict()
	usersToUpdateFeed = list()
	photosToNotifyAbout = dict()
	newPhotos = list()


	# Look through all the photos added, then grab the strandId and grab the users to notify from that
	for photo, strandId in photoToStrandIdDict.iteritems():
		for user in usersByStrandId[strandId]:
			if user.id != photo.user_id:
				# Record which photo is new for this user
				photosToNotifyAbout[user] = photo
				
				# Record that we want to notify this user about this photo's user
				if user not in usersToNotifyAboutById:
					usersToNotifyAboutById[user] = list()
				usersToNotifyAboutById[user].append(photo.user)
			
			usersToUpdateFeed.append(user)

		# New photos are used to look at their location and update feeds of nearby users
		newPhotos.append(photo)

	# Find folks who are not involved in these photos but are nearby instead
	# Loop through all newer photos and look for users nearby 
	#
	# TODO(Derek): Swap out this 3 for a constants var once that is figured out
	# TODO(Derek): Filter by friends who are actually in the feed (right now everyone in a strand)
	#    get a refreshFeed, even if they can't see the new photos
	#frequencyOfGpsUpdatesCutoff = now - datetime.timedelta(hours=3)
	#users = User.objects.filter(product_id=2).filter(last_location_timestamp__gt=frequencyOfGpsUpdatesCutoff)

	#for photo in newPhotos:
	#	nearbyUsers = geo_util.getNearbyUsers(photo.location_point.x, photo.location_point.y, users)

	#	usersToUpdateFeed.extend(nearbyUsers)
	
	usersWithoutRecentNot = list()
	for user in usersToUpdateFeed:
		# If the user is new, send the notitification
		if now < user.added + datetime.timedelta(seconds=20):
			usersWithoutRecentNot.append(user)
		elif user.id not in notificationsById:
			usersWithoutRecentNot.append(user)

	userIds = set(User.getIds(usersWithoutRecentNot))

	Thread(target=threadedSendNotifications, args=(userIds,)).start()


def processUserIdsForFriendGPSInfo(userIds):

	totalIn = len(userIds)
	processedOut = 0
	startTime = datetime.datetime.utcnow()
	
	logger.debug("Asked to get GPS info for friends of %s"%(userIds))
	friendSet = set()

	for userId in userIds:
		fullFriends, forwardFriends, reverseFriends, connIds = friends_util.getFriendsIds(userId)
		for friend in fullFriends:
			friendSet.add(friend)

	for userId in userIds:
		if userId in friendSet:
			friendSet.remove(userId)

	logger.debug("friends to ping: %s"%(friendSet))

	minTime = datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(minutes=constants.NOTIFICATIONS_GPS_FROM_FRIEND_INTERVAL_MINS) 
	recentlyPingedUsers = NotificationLog.objects.filter(added__gt=minTime).filter(msg_type=constants.NOTIFICATIONS_FETCH_GPS_ID).values('user').distinct()

	logger.debug("recentlyPingedUsers: %s"%(recentlyPingedUsers))

	for entry in recentlyPingedUsers:
		if entry['user'] in friendSet:
			friendSet.remove(entry['user'])

	friendList = list(friendSet)
	users = User.objects.filter(id__in=friendList)
	for user in users:
		processedOut += 1
		logger.debug("going to send a Fetch_GPS_ID to user id %s" % (user.id))
		customPayload = {}
		notifications_util.sendNotification(user, '', constants.NOTIFICATIONS_FETCH_GPS_ID, customPayload)

	endTime = datetime.datetime.utcnow()
	msTime = ((endTime-startTime).microseconds / 1000 + (endTime-startTime).seconds * 1000)
	return (totalIn, processedOut, "%s ms" % msTime)


# Look at strands that don't have location data and see if there's any location records which we could fill in for
def fillInLocationRecordData(user, strandsToProcess):
	strandsToProcess = sorted(strandsToProcess, key=lambda x: x.first_photo_time)
	timeLow = strandsToProcess[0].first_photo_time - datetime.timedelta(minutes=30)
	timeHigh =  strandsToProcess[-1].last_photo_time + datetime.timedelta(minutes=30)
	allLocationRecords = LocationRecord.objects.filter(Q(timestamp__gt=timeLow) & Q(timestamp__lt=timeHigh)).filter(user_id=user.id)

	updatedStrands = list()
	for strand in strandsToProcess:
		if strand.location_point:
			continue

		timeLow = strand.first_photo_time - datetime.timedelta(minutes=30)
		timeHigh = strand.last_photo_time + datetime.timedelta(minutes=30)

		bestLocationRecord = None
		for locationRecord in allLocationRecords:
			if locationRecord.timestamp > timeLow and locationRecord.timestamp < timeHigh:
				if not bestLocationRecord:
					bestLocationRecord = locationRecord
				elif locationRecord.accuracy < bestLocationRecord.accuracy:
					bestLocationRecord = locationRecord
		if bestLocationRecord:
			logger.debug("Found location record %s with accuracy %s for strand %s" % (bestLocationRecord.id, bestLocationRecord.accuracy, strand.id))

			strand.location_point = bestLocationRecord.point
			updatedStrands.append(strand)

	# Don't need to do neighboring code here 
	logger.debug("Filled in location for %s strands" % (len(updatedStrands)))
	return len(updatedStrands)

"""
	 Put all new photos into private strands.  Keep track of new private Strands
"""
def processBatch(photosToProcess):
	total = 0
	strandPhotosToCreate = list()
	strandUsersToCreate = list()

	timeWithinSecondsForNotification = 10 # seconds

	timeTakendelta = datetime.timedelta(hours=3)	

	# make a list of users whose photos are here
	userIdList = list()
	a = datetime.datetime.now()
	
	for photo in photosToProcess:
		if photo.time_taken > datetime.datetime.utcnow().replace(tzinfo=pytz.utc)-timeTakendelta:
			userIdList.append(photo.user_id)

	if len(userIdList) > 0:
		processUserIdsForFriendGPSInfoAppTask.delay(userIdList)

	# Group photos by users, then iterate through all users one at a time, fetching the cache as we go
	photosByUser = dict()
	for photo in photosToProcess:
		if photo.user not in photosByUser:
			photosByUser[photo.user] = list()
		photosByUser[photo.user].append(photo)


	for user, photos in photosByUser.iteritems():
		logger.debug("Starting a run with %s photos, took %s milli" % (len(photos), ((datetime.datetime.now()-a).microseconds/1000) + (datetime.datetime.now()-a).seconds*1000))
		b = datetime.datetime.now()
		strandsCreated = list()
		strandsAddedTo = list()
		strandsDeleted = 0

		photosByStrandId = dict()
		usersByStrandId = dict()
		allUsers = list()

		# Used for notifications
		photoToStrandIdDict = dict()
		photos = list(photos)

		timeHigh = photos[0].time_taken + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)
		timeLow = photos[-1].time_taken - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)

		strandsCache = list(Strand.objects.prefetch_related('users', 'photos').filter(user=user).filter(private=1).filter((Q(first_photo_time__gt=timeLow) & Q(first_photo_time__lt=timeHigh)) | (Q(last_photo_time__gt=timeLow) & Q(last_photo_time__lt=timeHigh))).filter(product_id=2))

		for strand in strandsCache:
			photosByStrandId[strand.id] = list(strand.photos.all())
			usersByStrandId[strand.id] = list(strand.users.all())
			allUsers.extend(strand.users.all())

			if len(strand.users.all()) == 0 or len(strand.photos.all()) == 0:
				strandsCache = dealWithDeadStrand(strand, strandsCache)

		allUsers = set(allUsers)

		c = datetime.datetime.now()
		logger.debug("Building Strands cache with %s strands took took %s milli" % (len(strandsCache), ((c-b).microseconds/1000) + (c-b).seconds*1000))

		for photo in photos:
			matchingStrands = list()

			for strand in strandsCache:		
				if strands_util.photoBelongsInStrand(photo, strand, photosByStrandId):
					matchingStrands.append(strand)
			
			if len(matchingStrands) == 1:
				strand = matchingStrands[0]
				if strands_util.addPhotoToStrand(strand, photo, photosByStrandId, usersByStrandId, strandPhotosToCreate, strandUsersToCreate):
					strandsAddedTo.append(strand)
					photoToStrandIdDict[photo] = strand.id
					
					logger.debug("Just added photo %s to strand %s users %s" % (photo.id, strand.id, usersByStrandId[strand.id]))
			elif len(matchingStrands) > 1:
				logger.debug("Found %s matching strands for photo %s, merging" % (len(matchingStrands), photo.id))
				targetStrand = matchingStrands[0]
				
				# Merge strands
				for i, strand in enumerate(matchingStrands):
					if i > 0:
						strands_util.mergeStrands(targetStrand, strand, photosByStrandId, usersByStrandId, strandPhotosToCreate, strandUsersToCreate)
						logger.debug("Merged strand %s into %s users %s" % (strand.id, targetStrand.id, usersByStrandId[targetStrand.id]))

				# Delete unneeded Srands
				for i, strand in enumerate(matchingStrands):
					if i > 0:
						# remove from our cache and db
						strandsCache = filter(lambda a: a.id != strand.id, strandsCache)
						logger.debug("Deleted strand %s" % strand.id)
						strand.delete()
						strandsDeleted += 1
				
				strandsAddedTo.append(targetStrand)
				photoToStrandIdDict[photo] = targetStrand.id
			else:
				newStrand = Strand.objects.create(user = user, first_photo_time = photo.time_taken, last_photo_time = photo.time_taken, location_point = photo.location_point, location_city = photo.location_city, private = True)
				newStrand.save()
				
				if strands_util.addPhotoToStrand(newStrand, photo, photosByStrandId, usersByStrandId, strandPhotosToCreate, strandUsersToCreate):
					strandsCreated.append(newStrand)
					strandsCache.append(newStrand)

					photoToStrandIdDict[photo] = newStrand.id

					logger.debug("Created new private Strand %s for photo %s and user %s" % (newStrand.id, photo.id, usersByStrandId[newStrand.id]))
	
			photo.strand_evaluated = True
		
		Photo.bulkUpdate(photos, ["strand_evaluated", "is_dup"])
		if len(strandPhotosToCreate) > 0:
			try:
				Strand.photos.through.objects.bulk_create(strandPhotosToCreate)
			except IntegrityError:
				try:
					for obj in strandPhotosToCreate:
						obj.save()
				except IntegrityError:
					pass

		if len(strandUsersToCreate) > 0:
			try:
				Strand.users.through.objects.bulk_create(strandUsersToCreate)
			except IntegrityError:
				try:
					for obj in strandUsersToCreate:
						obj.save()
				except IntegrityError:
					pass

		strandsToUpdate = list()
		for strand in strandsAddedTo:
			if not strand.cache_dirty:
				strand.cache_dirty = True
				strandsToUpdate.append(strand)

		Strand.bulkUpdate(strandsToUpdate, ['cache_dirty'])
		
		# We're doing this here instead of when the object was created
		# so we make sure everything is processed at a minimum level before neighboring starts
		# Note: now that we're doing async, this could go above if that is needed
		for strand in strandsCreated:
			strand.neighbor_evaluated = False

		# This looks at all the Location Records to see if one has a hint for location for a strand
		fillInLocationRecordData(user, strandsCreated)
		
		Strand.bulkUpdate(strandsCreated, ['neighbor_evaluated', 'location_point'])

		logger.debug("Created %s new strands and updated %s" % (len(strandsCreated), len(strandsAddedTo)))
		total += len(strandsCreated)
		total += len(strandsAddedTo)
		
		# Theoretically this could include a strand multiple times if another thread set the dirty bit
		ids = Strand.getIds(strandsAddedTo)
		ids.extend(Strand.getIds(strandsCreated))
		if len(ids) > 0:
			popcaches.processIds.delay(ids)

		if len(strandsCreated) > 0:
			neighboring.processStrandIds.delay(Strand.getIds(strandsCreated))
		if len(strandsAddedTo) > 0:
			suggestion_notifications.processIds.delay(Strand.getIds(strandsAddedTo))

		#logging.getLogger('django.db.backends').setLevel(logging.ERROR)
		
		#logger.debug("Starting sending notifications...")
		# Turning off notifications since the caching script should do this now.
		# If not, then turn this back on
		#sendNotifications(photoToStrandIdDict, usersByStrandId, timeWithinSecondsForNotification)

		logger.info("%s photos evaluated and %s strands created, %s strands added to, %s deleted.  Total run took: %s milli" % (len(photos), len(strandsCreated), len(strandsAddedTo), strandsDeleted, (((datetime.datetime.now()-a).microseconds/1000) + (datetime.datetime.now()-a).seconds*1000)))

	return total
baseQuery = Photo.objects.select_related().filter(strand_evaluated=False).filter(product_id=2).exclude(time_taken=None).order_by('-time_taken')
numToProcess = 50

@app.task
def processAll():
	return celery_helper.processBatch(baseQuery, numToProcess, processBatch)

@app.task
def processIds(ids):
	return celery_helper.processBatch(baseQuery.filter(id__in=ids), numToProcess, processBatch)

@app.task
def processUserIdsForFriendGPSInfoAppTask(userIds):
	return processUserIdsForFriendGPSInfo(userIds)



#!/usr/bin/python
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

from django.db.models import Count, Q

from peanut.settings import constants
from common.models import Photo, Strand, User, StrandNeighbor, StrandInvite

from strand import geo_util, friends_util, strands_util
import strand.notifications_util as notifications_util

logger = logging.getLogger(__name__)


def dealWithDeadStrand(strand, strandsCache):
	logging.error("populateStrands tried to eval strand %s with 0 users", (strand.id))
	# remove from our cache and db
	strandsCache = filter(lambda a: a.id != strand.id, strandsCache)
	logger.debug("Deleted strand %s" % strand.id)
	strand.delete()

	return strandsCache
	
def dealWithFirstRun(user):
	update = False
	if not user.first_run_sync_complete:
		if user.first_run_sync_count:
			# If there are no matching photos from the client, then sync is complete
			if user.first_run_sync_count == 0:
				update = True
			else:
				# If there are 
				strandInvites = StrandInvite.objects.select_related().filter(invited_user=user).exclude(skip=True).filter(accepted_user__isnull=True)
				if strandInvites.count() == 0:
					update = True
				else:
					lastStrandedPhotos = Photo.objects.filter(user=user, strand_evaluated=True).order_by('time_taken')[:1]
					if lastStrandedPhotos[0].time_taken <= strandInvites[0].strand.first_photo_time:
						update = True
					else:
						# This means that we have a count, but we haven't actually reached the right date
						#   this happens if the client is really fast uploading photos, then we might be stranding
						#   new photos and the invite was an old one.  We want to wait until we hit the age of the old one
						#   to make sure we find any matches
						pass
		else:
			# This means the client hasn't given us any information yet.
			# if this happens, then just see if we've stranded anything, if so, then call things good to go.
			lastStrandedPhotos = Photo.objects.filter(user=user, strand_evaluated=True).order_by('time_taken')[:1]
			if lastStrandedPhotos.count() > 0:
				update = True

	if update:
		user.first_run_sync_complete = True
		logger.info("Updated first_run_sync_complete for user %s", user)
		user.save()
		
def processWithExisting(existingNeighborRows, newNeighborRows):
	existing = dict()
	rowsToCreate = list()

	for row in existingNeighborRows:
		id1 = row.strand_1_id
		id2 = row.strand_2_id

		if id1 not in existing:
			existing[id1] = dict()
		existing[id1][id2] = True

	for newRow in newNeighborRows:
		id1 = newRow.strand_1_id
		id2 = newRow.strand_2_id

		if id1 in existing and id2 in existing[id1]:
			pass
		else:
			rowsToCreate.append(newRow)
	return rowsToCreate


def getAllStrandIds(neighborRows):
	strandIds = list()
	for row in neighborRows:
		strandIds.append(row.strand_1_id)
		strandIds.append(row.strand_2_id)

	return set(strandIds)


def threadedSendNotifications(userIds):
	logging.basicConfig(filename='/var/log/duffy/stranding.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	logger = logging.getLogger(__name__)

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

"""
	1. Put all new photos into private strands.  Keep track of new private Strands
	2. For each new private Strand, figure out its neighbors

"""
def main(argv):
	maxPhotosAtTime = 50
	timeWithinSecondsForNotification = 10 # seconds

	timeWithinMinutesForNeighboring = constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING
	
	logger.info("Starting... ")
	while True:
		a = datetime.datetime.now()
		photos = Photo.objects.select_related().filter(strand_evaluated=False).filter(product_id=2).exclude(time_taken=None).order_by('-time_taken')[:maxPhotosAtTime]
		
		if len(photos) == 0:
			time.sleep(.1)
			continue

		# Group photos by users, then iterate through all users one at a time, fetching the cache as we go
		photosByUser = dict()
		for photo in photos:
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

			timeHigh = photos[0].time_taken + datetime.timedelta(minutes=timeWithinMinutesForNeighboring)
			timeLow = photos[-1].time_taken - datetime.timedelta(minutes=timeWithinMinutesForNeighboring)

			strandsCache = list(Strand.objects.prefetch_related('users', 'photos').filter(user=user).filter(private=1).filter((Q(first_photo_time__gt=timeLow) & Q(first_photo_time__lt=timeHigh)) | (Q(last_photo_time__gt=timeLow) & Q(last_photo_time__lt=timeHigh))).filter(product_id=2))

			for strand in strandsCache:
				photosByStrandId[strand.id] = list(strand.photos.all())
				usersByStrandId[strand.id] = list(strand.users.all())
				allUsers.extend(strand.users.all())

				if len(strand.users.all()) == 0 or len(strand.photos.all()) == 0:
					dealWithDeadStrand(strand, strandsCache)

			allUsers = set(allUsers)

			c = datetime.datetime.now()
			logger.debug("Building Strands cache with %s strands took took %s milli" % (len(strandsCache), ((c-b).microseconds/1000) + (c-b).seconds*1000))

			for photo in photos:
				matchingStrands = list()
				strandNeighbors = list()

				for strand in strandsCache:		
					if strands_util.photoBelongsInStrand(photo, strand, photosByStrandId):
						matchingStrands.append(strand)
				
				if len(matchingStrands) == 1:
					strand = matchingStrands[0]
					if strands_util.addPhotoToStrand(strand, photo, photosByStrandId, usersByStrandId):
						strandsAddedTo.append(strand)
						photoToStrandIdDict[photo] = strand.id
						
						logger.debug("Just added photo %s to strand %s users %s" % (photo.id, strand.id, usersByStrandId[strand.id]))
				elif len(matchingStrands) > 1:
					logger.debug("Found %s matching strands for photo %s, merging" % (len(matchingStrands), photo.id))
					targetStrand = matchingStrands[0]
					
					# Merge strands
					for i, strand in enumerate(matchingStrands):
						if i > 0:
							strands_util.mergeStrands(targetStrand, strand, photosByStrandId, usersByStrandId)
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
					
					if strands_util.addPhotoToStrand(newStrand, photo, photosByStrandId, usersByStrandId):
						strandsCreated.append(newStrand)
						strandsCache.append(newStrand)

						photoToStrandIdDict[photo] = newStrand.id

						logger.debug("Created new private Strand %s for photo %s and user %s" % (newStrand.id, photo.id, usersByStrandId[newStrand.id]))
		
				photo.strand_evaluated = True
			
			Photo.bulkUpdate(photos, ["strand_evaluated", "is_dup"])

			dealWithFirstRun(user)

			logger.debug("Created %s new strands, now creating neighbor rows" % len(strandsCreated))


			# Now go find all the strand neighbor rows we need to create
			neighborRowsToCreate = list()
			if len(strandsCreated) > 0:
				strandNeighborsToCreate = list()

				# Doing this to prefetch the photos data...otherwise django is dumb
				strandsCreated = Strand.objects.prefetch_related('photos').filter(id__in=Strand.getIds(strandsCreated))
				
				ab = datetime.datetime.now()
				#logging.getLogger('django.db.backends').setLevel(logging.DEBUG)
				query = Strand.objects.prefetch_related('users', 'photos').exclude(location_point__isnull=True).exclude(user=user).filter(product_id=2)
				additional = Q()
				for strand in strandsCreated:
					timeHigh = strand.last_photo_time + datetime.timedelta(minutes=timeWithinMinutesForNeighboring)
					timeLow = strand.first_photo_time - datetime.timedelta(minutes=timeWithinMinutesForNeighboring)

					if strand.location_point:
						additional = Q(additional | (Q(last_photo_time__gt=timeLow) & Q(first_photo_time__lt=timeHigh) & Q(location_point__within=strand.location_point.buffer(1))))
					else:
						additional = Q(additional | (Q(last_photo_time__gt=timeLow) & Q(first_photo_time__lt=timeHigh)))

				query = query.filter(additional)

				possibleNeighbors = list(query)

				logger.debug("Found %s possible neighbors" % len(possibleNeighbors))

				strandsByStrandId = dict()
				for strand in strandsCreated:
					for possibleNeighbor in possibleNeighbors:
						if strands_util.strandsShouldBeNeighbors(strand, possibleNeighbor):
							usersByStrandId[possibleNeighbor.id] = list(possibleNeighbor.users.all())
							strandsByStrandId[strand.id] = strand
							strandsByStrandId[possibleNeighbor.id] = possibleNeighbor
							if possibleNeighbor.id < strand.id:
								strandNeighborsToCreate.append((possibleNeighbor.id, strand.id))
							else:
								strandNeighborsToCreate.append((strand.id, possibleNeighbor.id))

				logger.debug("Strand neighbor eval for took %s milli" % (((datetime.datetime.now()-ab).microseconds/1000) + (datetime.datetime.now()-ab).seconds*1000))

				# Now deal with strand neighbor rows
				# Dedup our new neighbor rows and process with existing ones in the database
				strandNeighborsToCreate = set(strandNeighborsToCreate)
				strandNeighbors = list()
				for t in strandNeighborsToCreate:
					id1, id2 = t
					strandNeighbors.append(StrandNeighbor(strand_1_id=id1, strand_1_private=strandsByStrandId[id1].private, strand_1_user=strandsByStrandId[id1].user, strand_2_id=id2, strand_2_private=strandsByStrandId[id2].private, strand_2_user=strandsByStrandId[id2].user))
				
				allIds = getAllStrandIds(strandNeighbors)
				existingRows = StrandNeighbor.objects.filter(strand_1__in=allIds).filter(strand_2_id__in=allIds)
				neighborRowsToCreate = processWithExisting(existingRows, strandNeighbors)
				StrandNeighbor.objects.bulk_create(neighborRowsToCreate)
			
			#logging.getLogger('django.db.backends').setLevel(logging.ERROR)
			
			logger.debug("Starting sending notifications...")
			sendNotifications(photoToStrandIdDict, usersByStrandId, timeWithinSecondsForNotification)

			logger.info("%s photos evaluated and %s strands created, %s strands added to, %s deleted, %s strand neighbors created.  Total run took: %s milli" % (len(photos), len(strandsCreated), len(strandsAddedTo), strandsDeleted, len(neighborRowsToCreate), (((datetime.datetime.now()-a).microseconds/1000) + (datetime.datetime.now()-a).seconds*1000)))

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/stranding.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])
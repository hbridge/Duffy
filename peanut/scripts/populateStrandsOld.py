#!/usr/bin/python
import sys, os
import time, datetime
import logging
import math
import pytz
from threading import Thread

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
	Commenting out since we're not notifying people close by anymore

	# For each user, look at all the new photos taken around them and construct a message for them
	#  With all the names in there
	for user, otherUsers in usersToNotifyAboutById.iteritems():
		otherUsers = set(otherUsers)

		# This does two database lookups
		# TODO(Derek): If we need speed, build this into a cache
		friendsData = friends_util.getFriendsData(user.id)

		otherUsers = friends_util.filterUsersByFriends(user.id, friendsData, otherUsers)

		names = list()
		for otherUser in otherUsers:
			names.append(otherUser.display_name)

		if len(names) > 0:
			msg = " & ".join(names) + " added new photos!"

			# If the user doesn't show up in the array then they haven't been notified in that time period
			if user.id not in notificationsById:
				logger.debug("Sending message '%s' to user %s" % (msg, user))
				customPayload = {'pid': photosToNotifyAbout[user].id}
				
				notifications_util.sendNotification(user, msg, msgType, customPayload)
			else:
				logger.debug("Was going to send message '%s' to user %s but they were messaged recently" % (msg, user))

	"""



"""
	Grab all photos that are not strandEvaluated and grab all strands from the last 24 hours
	for each photo, go through each strand and see if it fits the requirements
	If a photo meets requirements for two or more strands, then merge them.

	Requirements right now are that the photo is within 3 hours of any photo in a strand and within 100 meters of a photo

	TODO(Derek): Right now we're using Django's object model to deal with the strand connection mappings.  This is slow since it
	writes a new row for each loop.  Would be faster to manually write the table entries in a batch call
"""
def main(argv):
	maxPhotosAtTime = 50
	timeWithinSecondsForNotification = 10 # seconds

	timeWithinMinutesForNeighboring = constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING
	
	logger.info("Starting... ")
	while True:
		photos = Photo.objects.all().select_related().filter(strand_evaluated=False).exclude(time_taken=None).filter(user__product_id=2).order_by('-time_taken')[:maxPhotosAtTime]
		
		a = datetime.datetime.now()
		if len(photos) > 0:
			b = datetime.datetime.now()
			logger.debug("Starting a run with %s photos, took %s milli" % (len(photos), ((b-a).microseconds/1000) + (b-a).seconds*1000))
			strandsCreated = list()
			strandsAddedTo = list()
			strandsDeleted = 0

			photosByStrandId = dict()
			usersByStrandId = dict()
			allUsers = list()

			# Used for notifications
			photoToStrandIdDict = dict()
			photos = list(photos)

			strandNeighborsToCreate = list()

			timeHigh = photos[0].time_taken + datetime.timedelta(minutes=timeWithinMinutesForNeighboring)
			timeLow = photos[-1].time_taken - datetime.timedelta(minutes=timeWithinMinutesForNeighboring)

			strandsCache = list(Strand.objects.prefetch_related('users', 'photos').filter((Q(first_photo_time__gt=timeLow) & Q(first_photo_time__lt=timeHigh)) | (Q(last_photo_time__gt=timeLow) & Q(last_photo_time__lt=timeHigh))).filter(product_id=2))

			for strand in strandsCache:
				photosByStrandId[strand.id] = list(strand.photos.all())
				usersByStrandId[strand.id] = list(strand.users.all())
				allUsers.extend(strand.users.all())

			allUsers = set(allUsers)

			c = datetime.datetime.now()
			logger.debug("Building Strands cache with %s strands took took %s milli" % (len(strandsCache), ((c-b).microseconds/1000) + (c-b).seconds*1000))

			for photo in photos:
				matchingStrands = list()
				strandNeighbors = list()

				for strand in strandsCache:		
					if not strand.private and strand.users.count() == 0:
						logging.error("populateStrands tried to eval strand %s with 0 users", (strand.id))
						# remove from our cache and db
						strandsCache = filter(lambda a: a.id != strand.id, strandsCache)
						logger.debug("Deleted strand %s" % strand.id)
						strand.delete()
						continue
					
					if strands_util.photoBelongsInStrand(photo, strand, photosByStrandId):
						# If this is a private strand and the photo doesn't belong to the strand's user
						#   then create strand neighbor entry
						if strand.private and photo.user_id != strand.user_id:
							strandNeighbors.append(strand)
						# If the photo wasn't taken with strand (is private) and the strand is shared
						#    then create a strand neighbor entry
						elif not photo.taken_with_strand and not strand.private:
							strandNeighbors.append(strand)
						else:
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
					# If we're creating a strand with a photo that wasn't taken with strand, then turn off sharing
					private = not photo.taken_with_strand
					
					newStrand = Strand(first_photo_time = photo.time_taken, last_photo_time = photo.time_taken, private = private)
					if private:
						newStrand.user = photo.user

					newStrand.save()
					
					if strands_util.addPhotoToStrand(newStrand, photo, photosByStrandId, usersByStrandId):
						strandsCreated.append(newStrand)
						strandsCache.append(newStrand)

						photoToStrandIdDict[photo] = newStrand.id

						logger.debug("Created new Strand %s for photo %s and user %s.  private = %s" % (newStrand.id, photo.id, usersByStrandId[newStrand.id], private))
		
				# If our photo got put into a strand (it might not incase there was a dup already in it)
				#    Then we figure out which strand it got put in and go through each strand neighbor
				#    we marked off and create the strandNeighbor row for later
				if photo in photoToStrandIdDict:
					finalStrandId = photoToStrandIdDict[photo]
					strandNeighbors = set(strandNeighbors)
					# Now create the StrandNeighbor rows
					for strand in strandNeighbors:
						
						if strand.id < finalStrandId:
							# Add in a tuple because we're going do dedup later
							strandNeighborsToCreate.append((strand.id, finalStrandId))
						else:
							strandNeighborsToCreate.append((finalStrandId, strand.id))

				photo.strand_evaluated = True
			
			Photo.bulkUpdate(photos, ["strand_evaluated"])

			# Now deal with strand neighbor rows
			# Dedup our new neighbor rows and process with existing ones in the database
			strandNeighborsToCreate = set(strandNeighborsToCreate)
			strandNeighbors = list()
			for t in strandNeighborsToCreate:
				id1, id2 = t
				strandNeighbors.append(StrandNeighbor(strand_1_id=id1, strand_2_id=id2))
			
			allIds = getAllStrandIds(strandNeighbors)
			existingRows = StrandNeighbor.objects.filter(strand_1__in=allIds).filter(strand_2_id__in=allIds)
			neighborRowsToCreate = processWithExisting(existingRows, strandNeighbors)
			StrandNeighbor.objects.bulk_create(neighborRowsToCreate)	
			
			logger.debug("Starting sending notifications...")
			
			sendNotifications(photoToStrandIdDict, usersByStrandId, timeWithinSecondsForNotification)

			# Deal with first run sync scenarios
			usersToUpdate = list()
			for user in allUsers:
				if not user.first_run_sync_complete:
					if user.first_run_sync_count:
						# If there are no matching photos from the client, then sync is complete
						if user.first_run_sync_count == 0:
							usersToUpdate.append(user)
						else:
							# If there are 
							strandInvites = StrandInvite.objects.select_related().filter(invited_user=user).exclude(skip=True).filter(accepted_user__isnull=True)
							if strandInvites.count() == 0:
								usersToUpdate.append(user)
							else:
								lastStrandedPhotos = Photo.objects.filter(user=user, strand_evaluated=True).order_by('time_taken')[:1]
								if lastStrandedPhotos[0].time_taken <= strandInvites[0].strand.first_photo_time:
									usersToUpdate.append(user)
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
							usersToUpdate.append(user)

			if len(usersToUpdate) > 0:
				for user in usersToUpdate:
					user.first_run_sync_complete = True
					logger.info("Updated first_run_sync_complete for user %s", user)
				User.bulkUpdate(usersToUpdate, 'first_run_sync_complete')

			logger.info("%s photos evaluated and %s strands created, %s strands added to, %s deleted, %s strand neighbors created" % (len(photos), len(strandsCreated), len(strandsAddedTo), strandsDeleted, len(strandNeighborsToCreate)))
		else:
			time.sleep(.1)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/stranding.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
#!/usr/bin/python
import sys, os
import time, datetime
import logging
import math
import pytz

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

from django.db.models import Count

from peanut.settings import constants
from common.models import Photo, Strand, User

from strand import geo_util, friends_util, strands_util
import strand.notifications_util as notifications_util

logger = logging.getLogger(__name__)

"""
	Takes in:
	photosAndStrandDict - Dictionary key being a photo and value the strandId
	usersByStrandId - Dictionary key being a strandId and value a list of users in the strand

"""
def sendNotifications(photoToStrandIdDict, usersByStrandId, timeWithinSecondsForNotification):
	msgType = constants.NOTIFICATIONS_NEW_PHOTO_ID
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	notificationLogsCutoff = now - datetime.timedelta(seconds=timeWithinSecondsForNotification)
	
	# Grab logs from last 30 seconds (default) then grab the last time they were notified
	notificationLogs = notifications_util.getNotificationLogs(notificationLogsCutoff)
	notificationsById = notifications_util.getNotificationsForTypeByIds(notificationLogs, [msgType, constants.NOTIFICATIONS_JOIN_STRAND_ID])

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
	frequencyOfGpsUpdatesCutoff = now - datetime.timedelta(hours=3)
	users = User.objects.filter(product_id=1).filter(last_location_timestamp__gt=frequencyOfGpsUpdatesCutoff)

	for photo in newPhotos:
		nearbyUsers = geo_util.getNearbyUsers(photo.location_point.x, photo.location_point.y, users)

		usersToUpdateFeed.extend(nearbyUsers)
		
	# Send update feed msg to folks who are involved in these photos
	notifications_util.sendRefreshFeedToUsers(set(usersToUpdateFeed))

	

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
	Grab all photos that are not strandEvaluated and grab all strands from the last 24 hours
	for each photo, go through each strand and see if it fits the requirements
	If a photo meets requirements for two or more strands, then merge them.

	Requirements right now are that the photo is within 3 hours of any photo in a strand and within 100 meters of a photo

	TODO(Derek): Right now we're using Django's object model to deal with the strand connection mappings.  This is slow since it
	writes a new row for each loop.  Would be faster to manually write the table entries in a batch call
"""
def main(argv):
	maxPhotosAtTime = 100
	timeWithinSecondsForNotification = 30 # seconds

	timeWithinMinutesForNeighboring = constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING
	
	logger.info("Starting... ")
	while True:
		photos = Photo.objects.all().exclude(location_point=None).filter(strand_evaluated=False).exclude(time_taken=None).filter(user__product_id=1).order_by('-time_taken')[:maxPhotosAtTime]

		if len(photos) > 0:
			strandsCreated = list()
			strandsAddedTo = list()
			strandsDeleted = 0

			photosByStrandId = dict()
			usersByStrandId = dict()

			# Used for notifications
			photoToStrandIdDict = dict()
			photos = list(photos)

			timeHigh = photos[0].time_taken + datetime.timedelta(minutes=timeWithinMinutesForNeighboring)
			timeLow = photos[-1].time_taken - datetime.timedelta(minutes=timeWithinMinutesForNeighboring)

			strandsCache = list(Strand.objects.select_related().filter(time_started__gt=timeLow).filter(last_photo_time__lt=timeHigh))

			for strand in strandsCache:
				photosByStrandId[strand.id] = list(strand.photos.all())
				usersByStrandId[strand.id] = list(strand.users.all())

			for photo in photos:
				matchingStrands = list()

				for strand in strandsCache:
					users = strand.users.all()

					if len(users) == 0:
						logging.error("populateStrands tried to eval strand %s with 0 users", (strand.id))
						continue
					
					# If this is a non-shared strand (solo) and the photo doesn't belong to the strand's user, don't match
					if not strand.shared and photo.user_id != users[0].id:
						continue
					
					# If the photo wasn't taken with strand (is private) and the strand is shared, don't match
					if not photo.taken_with_strand and strand.shared:
						continue
						
					if strands_util.photoBelongsInStrand(photo, strand, photosByStrandId):
						matchingStrands.append(strand)
				
				if len(matchingStrands) == 1:
					strand = matchingStrands[0]
					strands_util.addPhotoToStrand(strand, photo, photosByStrandId, usersByStrandId)
					strandsAddedTo.append(strand)
					photoToStrandIdDict[photo] = strand.id
					
					logger.debug("Just added photo %s to strand %s" % (photo.id, strand.id))
				elif len(matchingStrands) > 1:
					logger.debug("Found %s matching strands for photo %s, merging" % (len(matchingStrands), photo.id))
					targetStrand = matchingStrands[0]
					
					# Merge strands
					for i, strand in enumerate(matchingStrands):
						if i > 0:
							strands_util.mergeStrands(targetStrand, strand, photosByStrandId, usersByStrandId)
							logger.debug("Merged strand %s into %s" % (strand.id, targetStrand.id))

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
					shared = photo.taken_with_strand
					
					newStrand = Strand.objects.create(time_started = photo.time_taken, last_photo_time = photo.time_taken, shared = shared)
					strands_util.addPhotoToStrand(newStrand, photo, photosByStrandId, usersByStrandId)
					strandsCreated.append(newStrand)
					strandsCache.append(newStrand)

					photoToStrandIdDict[photo] = newStrand.id

					logger.debug("Created new Strand %s for photo %s.  shared = %s" % (newStrand.id, photo.id, shared))
	
				photo.strand_evaluated = True
				
			logger.info("%s photos evaluated and %s strands created, %s strands added to, %s deleted" % (len(photos), len(strandsCreated), len(strandsAddedTo), strandsDeleted))
			Photo.bulkUpdate(photos, ["strand_evaluated"])

			sendNotifications(photoToStrandIdDict, usersByStrandId, timeWithinSecondsForNotification)
		else:
			time.sleep(.1)	

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/stranding.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
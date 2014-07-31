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
from common.models import Photo, Strand

from strand import geo_util
import strand.notifications_util as notifications_util

logger = logging.getLogger(__name__)

def photoBelongsInStrand(targetPhoto, strand, photosByStrandId):
	for photo in photosByStrandId[strand.id]:
		timeDiff = photo.time_taken - targetPhoto.time_taken
		if ( (timeDiff.total_seconds() / 60) < constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING ):
			if not photo.location_point and not photo.location_point:
				return True

			if (photo.location_point and targetPhoto.location_point and 
				geo_util.getDistanceBetweenPhotos(photo, targetPhoto) < constants.DISTANCE_WITHIN_METERS_FOR_NEIGHBORING):
				return True

	return False

def addPhotoToStrand(strand, photo, photosByStrandId, usersByStrandId):
	if photo.time_taken > strand.last_photo_time:
		strand.last_photo_time = photo.time_taken

	if photo.time_taken < strand.time_started:
		strand.time_started = photo.time_taken
	
	if strand.id not in photosByStrandId:
		# Handle case that this is a new strand
		strand.photos.add(photo)
		photosByStrandId[strand.id] = [photo]
	elif photo not in photosByStrandId[strand.id]:
		strand.photos.add(photo)
		photosByStrandId[strand.id].append(photo)

	if strand.id not in usersByStrandId:
		# Handle case that this is a new strand
		strand.users.add(photo.user)
		usersByStrandId[strand.id]= [photo.user]
	elif photo.user not in usersByStrandId[strand.id]:
		strand.users.add(photo.user)
		usersByStrandId[strand.id].append(photo.user)
		
		
def mergeStrands(strand1, strand2, photosByStrandId, usersByStrandId):
	photoList = photosByStrandId[strand2.id]
	for photo in photoList:
		if photo not in photosByStrandId[strand1.id]:
			addPhotoToStrand(strand1, photo, photosByStrandId, usersByStrandId)

	userList = usersByStrandId[strand2.id]
	for user in userList:
		if user not in usersByStrandId[strand1.id]:
			strand1.users.add(user)
			usersByStrandId[strand1.id].append(user)

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
		photos = Photo.objects.all().exclude(thumb_filename=None).filter(strand_evaluated=False).exclude(time_taken=None).filter(user__product_id=1).order_by('-time_taken')[:maxPhotosAtTime]

		if len(photos) > 0:
			strandsCreated = list()
			strandsAddedTo = list()
			strandsDeleted = 0

			photosByStrandId = dict()
			usersByStrandId = dict()
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
					if photoBelongsInStrand(photo, strand, photosByStrandId):
						matchingStrands.append(strand)
				
				if len(matchingStrands) == 1:
					strand = matchingStrands[0]
					addPhotoToStrand(strand, photo, photosByStrandId, usersByStrandId)
					strandsAddedTo.append(strand)
					
					logger.debug("Just added photo %s to strand %s" % (photo.id, strand.id))
				elif len(matchingStrands) > 1:
					logger.debug("Found %s matching strands for photo %s, merging" % (len(matchingStrands), photo.id))
					targetStrand = matchingStrands[0]
					
					# Merge strands
					for i, strand in enumerate(matchingStrands):
						if i > 0:
							mergeStrands(targetStrand, strand, photosByStrandId, usersByStrandId)
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
				else:
					newStrand = Strand.objects.create(time_started = photo.time_taken, last_photo_time = photo.time_taken)
					addPhotoToStrand(newStrand, photo, photosByStrandId, usersByStrandId)
					strandsCreated.append(newStrand)
					strandsCache.append(newStrand)
					logger.debug("Created new Strand %s for photo %s" % (newStrand.id, photo.id))

				photo.strand_evaluated = True
				
			logger.info("%s photos evaluated and %s strands created, %s strands added to, %s deleted" % (len(photos), len(strandsCreated), len(strandsAddedTo), strandsDeleted))
			Photo.bulkUpdate(photos, ["strand_evaluated"])

		else:
			time.sleep(1)	

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/stranding.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
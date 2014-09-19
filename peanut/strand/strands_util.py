#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging

from peanut.settings import constants

from strand import geo_util, friends_util

logger = logging.getLogger(__name__)

"""
	Utility method to grab all photos that are in a joinable strand near the given lat, lon
	Also, filters by friends of the userId
"""
def getJoinableStrandPhotos(userId, lon, lat, strands, friendsData):
	timeWithinMinutes = constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING

	nowTime = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)

	joinableStrands = list()
	for strand in strands:
		if userId not in [x.id for x in strand.users.all()]:
			for photo in strand.photos.all():
				# See if a photo was taken now and in the location, would it belong in this strand
				# TODO(Derek):  This could probably be pulled out and shared with populateStrands
				timeDiff = nowTime - photo.time_taken
				if ( (timeDiff.total_seconds() / 60) < constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING and
					geo_util.getDistanceToPhoto(lon, lat, photo) < constants.DISTANCE_WITHIN_METERS_FOR_NEIGHBORING):
					joinableStrands.append(strand)

	joinableStrands = set(joinableStrands)

	photos = list()
	for strand in joinableStrands:
		photos.extend(friends_util.filterStrandPhotosByFriends(userId, friendsData, strand))

	return photos


def photoBelongsInStrand(targetPhoto, strand, photosByStrandId = None):
	if photosByStrandId:
		photosInStrand = photosByStrandId[strand.id]
	else:
		photosInStrand = strand.photos.all()

	for photo in photosInStrand:
		timeDiff = photo.time_taken - targetPhoto.time_taken
		if ( (abs(timeDiff.total_seconds()) / 60) < constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING ):
			if not photo.location_point and not photo.location_point:
				return True

			if (photo.location_point and targetPhoto.location_point and 
				geo_util.getDistanceBetweenPhotos(photo, targetPhoto) < constants.DISTANCE_WITHIN_METERS_FOR_NEIGHBORING):
				return True

	return False

def addPhotoToStrand(strand, photo, photosByStrandId, usersByStrandId):
	if photo.time_taken > strand.last_photo_time:
		strand.last_photo_time = photo.time_taken
		strand.save()

	if photo.time_taken < strand.first_photo_time:
		strand.first_photo_time = photo.time_taken
		strand.save()
	
	if strand.id not in photosByStrandId:
		# Handle case that this is a new strand
		strand.photos.add(photo)
		photosByStrandId[strand.id] = [photo]
	elif photo not in photosByStrandId[strand.id]:
		for p in photosByStrandId[strand.id]:
			if p.iphone_hash == photo.iphone_hash:
				logger.debug("Found a hash conflict in strand %s for photo %s" % (strand.id, photo.id))
				return False

		strand.photos.add(photo)
		photosByStrandId[strand.id].append(photo)

	if strand.id not in usersByStrandId:
		# Handle case that this is a new strand
		usersByStrandId[strand.id]= [photo.user]

		if strand.shared:
			strand.users.add(photo.user)

	elif photo.user not in usersByStrandId[strand.id]:
		usersByStrandId[strand.id].append(photo.user)

		if strand.shared:
			strand.users.add(photo.user)
	return True
		
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
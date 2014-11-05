#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging
import json

from peanut.settings import constants

from strand import geo_util, friends_util

from common.models import Strand

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


def photoBelongsInStrand(targetPhoto, strand, photosByStrandId = None, honorLocation = True):
	if photosByStrandId:
		photosInStrand = photosByStrandId[strand.id]
	else:
		photosInStrand = strand.photos.all()

	for photo in photosInStrand:
		timeDiff = photo.time_taken - targetPhoto.time_taken
		timeDiffMin = abs(timeDiff.total_seconds()) / 60
		if ( timeDiffMin < constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING ):
			if honorLocation:
				if not photo.location_point and not targetPhoto.location_point:
					return True

				if (photo.location_point and targetPhoto.location_point and 
					geo_util.getDistanceBetweenPhotos(photo, targetPhoto) < constants.DISTANCE_WITHIN_METERS_FOR_NEIGHBORING):
					return True
			else:
				return True
	return False


def strandsShouldBeNeighbors(strand, possibleNeighbor, noLocationTimeLimitMin = constants.MINUTES_FOR_NOLOC_NEIGHBORING):
	if ((strand.last_photo_time + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING) > possibleNeighbor.first_photo_time) and
		(strand.first_photo_time - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING) < possibleNeighbor.last_photo_time)):

		if not strand.location_point or not possibleNeighbor.location_point:
			for photo1 in strand.photos.all():
				for photo2 in possibleNeighbor.photos.all():
					timeDiff = photo1.time_taken - photo2.time_taken
					timeDiffMin = abs(timeDiff.total_seconds()) / 60

					if timeDiffMin < noLocationTimeLimitMin:
						return True
		elif (strand.location_point and possibleNeighbor.location_point and 
			geo_util.getDistanceBetweenStrands(strand, possibleNeighbor) < constants.DISTANCE_WITHIN_METERS_FOR_NEIGHBORING):
			return True
		
	return False
	
def addPhotoToStrand(strand, photo, photosByStrandId, usersByStrandId):
	if photo.time_taken > strand.last_photo_time:
		strand.last_photo_time = photo.time_taken
		strand.save()

	if photo.time_taken < strand.first_photo_time:
		strand.first_photo_time = photo.time_taken
		strand.location_point = photo.location_point
		strand.location_city = photo.location_city
		strand.save()
	
	# Add photo to strand
	#   Don't add in if there's a dup in it already though
	if strand.id not in photosByStrandId:
		# Handle case that this is a new strand
		Strand.photos.through.objects.create(strand=strand, photo=photo)
		photosByStrandId[strand.id] = [photo]
	elif photo not in photosByStrandId[strand.id]:
		for p in photosByStrandId[strand.id]:
			if p.iphone_hash == photo.iphone_hash:
				logger.debug("Found a hash conflict in strand %s for photo %s" % (strand.id, photo.id))
				return False

		Strand.photos.through.objects.create(strand=strand, photo=photo)
		photosByStrandId[strand.id].append(photo)

	# Add user to strand
	if strand.id not in usersByStrandId:
		# Handle case that this is a new strand
		usersByStrandId[strand.id]= [photo.user]
		Strand.users.through.objects.create(strand=strand, user=photo.user)

	elif photo.user not in usersByStrandId[strand.id]:
		usersByStrandId[strand.id].append(photo.user)
		Strand.users.through.objects.create(strand=strand, user=photo.user)
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


def getBestLocation(photo):
	if photo.twofishes_data:
		twoFishesData = json.loads(photo.twofishes_data)
		bestLocationName = None
		bestWoeType = 100
		if "interpretations" in twoFishesData:
			for data in twoFishesData["interpretations"]:
				if "woeType" in data["feature"]:
					# https://github.com/foursquare/twofishes/blob/master/interface/src/main/thrift/geocoder.thrift
					if data["feature"]["woeType"] < bestWoeType:
						bestLocationName = data["feature"]["displayName"]
						bestWoeType = data["feature"]["woeType"]
						if bestLocationName:
							return bestLocationName
						else:
							return photo.location_city
	return None
	
def getBestLocationForPhotos(photos):
	# Grab title from the location_city of a photo...but find the first one that has
	#   a valid location_city
	bestLocation = None
	i = 0
	while (not bestLocation) and i < len(photos):
		bestLocation = getBestLocation(photos[i])
		i += 1

	return bestLocation

def getTitleForStrand(strand):
	photos = strand.photos.all()
	if len(photos) == 0:
		photos = strand.getPostPhotos()
		
	location = getBestLocationForPhotos(photos)

	dateStr = "%s %s" % (strand.first_photo_time.strftime("%b"), strand.first_photo_time.strftime("%d").lstrip('0'))

	if strand.first_photo_time.year != datetime.datetime.now().year:
		dateStr += ", " + strand.first_photo_time.strftime("%Y")

	title = dateStr

	if location:
		title = location + " on " + dateStr

	return title

def getLocationForStrand(strand):
	photos = strand.photos.all()
	if len(photos) == 0:
		photos = strand.getPostPhotos()
		
	location = getBestLocationForPhotos(photos)

	return location

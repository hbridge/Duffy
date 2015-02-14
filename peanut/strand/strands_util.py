#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging
import json

from django.db import IntegrityError
from django.db.models import Q

from peanut.settings import constants

from strand import geo_util, friends_util

from common.models import Strand, StrandNeighbor, Photo, Action, ShareInstance, User

logger = logging.getLogger(__name__)


def photoBelongsInStrand(targetPhoto, strand, photosByStrandId = None, honorLocation = True, distanceLimit = constants.DISTANCE_WITHIN_METERS_FOR_ROUGH_NEIGHBORING):
	if photosByStrandId:
		photosInStrand = photosByStrandId[strand.id]
	else:
		photosInStrand = strand.photos.all()

	for photo in photosInStrand:
		timeDiff = photo.time_taken - targetPhoto.time_taken
		timeDiffMin = abs(timeDiff.total_seconds()) / 60
		if (timeDiffMin < constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING):
			if honorLocation:
				if not photo.location_point and not targetPhoto.location_point:
					return True

				if (photo.location_point and targetPhoto.location_point and 
					geo_util.getDistanceBetweenPhotos(photo, targetPhoto) < distanceLimit):
					return True
			else:
				return True
	return False

def strandsShouldBeNeighbors(strand, possibleNeighbor, noLocationTimeLimitMin = constants.MINUTES_FOR_NOLOC_NEIGHBORING, distanceLimit = constants.DISTANCE_WITHIN_METERS_FOR_ROUGH_NEIGHBORING, locationRequired = True, doNoLocation = False):
	if ((strand.last_photo_time + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING) > possibleNeighbor.first_photo_time) and
		(strand.first_photo_time - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING) < possibleNeighbor.last_photo_time)):
		
		if (not locationRequired and (not strand.location_point or not possibleNeighbor.location_point)):
			if doNoLocation:
				for photo1 in strand.photos.all():
					for photo2 in possibleNeighbor.photos.all():
						timeDiff = photo1.time_taken - photo2.time_taken
						timeDiffMin = abs(timeDiff.total_seconds()) / 60

						if timeDiffMin < noLocationTimeLimitMin and abs(timeDiff.total_seconds()) > 1:
							return True, "noloc-%s" % timeDiff.total_seconds()
		
		elif (strand.location_point and possibleNeighbor.location_point and 
			geo_util.getDistanceBetweenStrands(strand, possibleNeighbor) < distanceLimit):
			return True, "location-%s" % geo_util.getDistanceBetweenStrands(strand, possibleNeighbor)
	return False, ""

def userShouldBeNeighborToStrand(strand, locationRecord):
	if strand.location_point:
		dist = geo_util.getDistanceBetweenStrandAndLocationRecord(strand, locationRecord)
		timeLow = strand.first_photo_time - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)
		timeHigh = strand.last_photo_time + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)
		if (dist < constants.DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING and
			 locationRecord.timestamp > timeLow and
			 locationRecord.timestamp < timeHigh):
			return True
			
	return False

	
def addPhotoToStrand(strand, photo, photosByStrandId, usersByStrandId, strandPhotosToCreate, strandUsersToCreate):
	if photo.time_taken > strand.last_photo_time:
		strand.last_photo_time = photo.time_taken
		strand.save()

	if photo.time_taken < strand.first_photo_time:
		strand.first_photo_time = photo.time_taken
		if photo.location_point:
			strand.location_point = photo.location_point
			strand.location_city = photo.location_city
		strand.save()

	if not strand.location_point and photo.location_point:
		strand.location_point = photo.location_point
		strand.location_city = photo.location_city	
		strand.save()
	
	# Add photo to strand
	#   Don't add in if there's a dup in it already though
	if strand.id not in photosByStrandId:
		# Handle case that this is a new strand
		strandPhotosToCreate.append(Strand.photos.through(strand=strand, photo=photo))
		photosByStrandId[strand.id] = [photo]
	elif photo not in photosByStrandId[strand.id]:
		for p in photosByStrandId[strand.id]:
			if p.iphone_hash == photo.iphone_hash:
				logger.debug("Found a hash conflict in strand %s for photo %s...marking as is_dup" % (strand.id, photo.id))
				photo.is_dup = True
				return False

		strandPhotosToCreate.append(Strand.photos.through(strand=strand, photo=photo))
		photosByStrandId[strand.id].append(photo)
		
	# Add user to strand
	if strand.id not in usersByStrandId:
		# Handle case that this is a new strand
		usersByStrandId[strand.id]= [photo.user]
		strandUsersToCreate.append(Strand.users.through(strand=strand, user=photo.user))

	elif photo.user not in usersByStrandId[strand.id]:
		usersByStrandId[strand.id].append(photo.user)
		strandUsersToCreate.append(Strand.users.through(strand=strand, user=photo.user))
	return True
		
def mergeStrands(strand1, strand2, photosByStrandId, usersByStrandId, strandPhotosToCreate, strandUsersToCreate):
	photoList = photosByStrandId[strand2.id]
	for photo in photoList:
		if photo not in photosByStrandId[strand1.id]:
			addPhotoToStrand(strand1, photo, photosByStrandId, usersByStrandId, strandPhotosToCreate, strandUsersToCreate)

	userList = usersByStrandId[strand2.id]
	for user in userList:
		if user not in usersByStrandId[strand1.id]:
			strandUsersToCreate.append(Strand.users.through(strand=strand2, user=user))
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
		location = strand.location_city
	else:
		location = getBestLocationForPhotos(photos)

	return location



def getAllStrandIds(neighborRows):
	strandIds = list()
	for row in neighborRows:
		if row.strand_1_id:
			strandIds.append(row.strand_1_id)
		if row.strand_2_id:
			strandIds.append(row.strand_2_id)

	return set(strandIds)


def processWithExisting(existingNeighborRows, newNeighborRows):
	existing = dict()
	rowsToCreate = list()
	rowsToUpdate = list()

	# Create a double dict of [id1][id2] for lookup in the next phase
	for row in existingNeighborRows:
		id1 = row.strand_1_id

		if row.strand_2_id:
			id2 = row.strand_2_id
		else:
			id2 = row.strand_2_user_id

		if id1 not in existing:
			existing[id1] = dict()
		existing[id1][id2] = row

	for newRow in newNeighborRows:
		id1 = newRow.strand_1_id
		if newRow.strand_2_id:
			id2 = newRow.strand_2_id
		else:
			id2 = newRow.strand_2_user_id

		if id1 in existing and id2 in existing[id1]:
			existingRow = existing[id1][id2]
			# If we have a new row with a smaller distance_in_meters, update the db with that one
			if (newRow.distance_in_meters and
				existingRow.distance_in_meters and 
				existingRow.distance_in_meters > newRow.distance_in_meters):
				existingRow.distance_in_meters = newRow.distance_in_meters
				rowsToUpdate.append(existingRow)
		else:
			rowsToCreate.append(newRow)
	return rowsToCreate, rowsToUpdate

def updateOrCreateStrandNeighbors(strandNeighbors):
	allIds = getAllStrandIds(strandNeighbors)
	existingRows = StrandNeighbor.objects.filter(strand_1_id__in=allIds).filter(Q(strand_2_id__in=allIds) | Q(strand_2_id__isnull=True))
	neighborRowsToCreate, neighborRowsToUpdate = processWithExisting(existingRows, strandNeighbors)
	
	try:
		StrandNeighbor.objects.bulk_create(neighborRowsToCreate)
	except IntegrityError:
		for row in neighborRowsToCreate:
			try:
				row.save()
			except IntegrityError:
				logger.error("Got IntegrityError trying to save %s %s" % (row.strand_1_id, row.strand_2_id))

	StrandNeighbor.bulkUpdate(neighborRowsToUpdate, ["distance_in_meters"])

	return neighborRowsToCreate, neighborRowsToUpdate

def checkStrandForAllPhotosEvaluated(strand):
	if strand:
		photoIds = Photo.getIds(strand.photos.all())

		actions = Action.objects.filter(photo_id__in=photoIds).filter(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED)

		notSeenPhotoIds = photoIds
		for action in actions:
			if action.photo_id in notSeenPhotoIds:
				notSeenPhotoIds.remove(action.photo_id)
				
		if len(notSeenPhotoIds) == 0:
			logger.debug("All photos have been seen for strand %s, marking as suggestible = False" % strand.id)
			strand.suggestible = False
			strand.save()
		else:
			logger.debug("Created action and had %s photos till not seen in the strand: %s" % (len(notSeenPhotoIds), notSeenPhotoIds))


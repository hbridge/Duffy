#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging

from peanut.settings import constants

from strand import geo_util, friends_util


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
from __future__ import absolute_import
import sys, os
import time, datetime
import logging
import urllib2
import urllib
import json
import pytz
from django.db.models import Q
from django import db

from common.models import Photo
from common import location_util

from peanut.celery import app

from async import celery_helper
from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)


def chunks(l, n):
	""" Yield successive n-sized chunks from l.
	"""
	for i in xrange(0, len(l), n):
		yield l[i:i+n]
		
"""
	Makes call to twofishes and gets back raw json
"""
def getDataFromTwoFishes(lat, lon):
	queryStr = "%s,%s" % (lat, lon)
	twoFishesParams = { "ll" : queryStr }

	twoFishesUrl = "http://demo.twofishes.net/?%s" % (urllib.urlencode(twoFishesParams)) 

	twoFishesResult = urllib2.urlopen(twoFishesUrl).read()

	if (twoFishesResult):
		return twoFishesResult
	return None

"""
	Makes call to twofishes and gets back raw json
"""
def getDataFromTwoFishesBulk(latLonList):
	resultList = list()

	for chunk in chunks(latLonList, 25):
		params = list()
		for latLonPair in chunk:
			params.append("ll=%s,%s" % latLonPair)
		params.append("method=bulkrevgeo")

		twoFishesParams = '&'.join(params)

		twoFishesUrl = "http://demo.twofishes.net/?%s" % (twoFishesParams)

		logger.debug("Requesting URL:  %s" % twoFishesUrl)
		twoFishesResultJson = urllib2.urlopen(twoFishesUrl).read()
		
		if (twoFishesResultJson):
			twoFishesResult = json.loads(twoFishesResultJson)
			for batch in twoFishesResult["interpretationIndexes"]:
				result = list()
				for index in batch:
					result.append(twoFishesResult["interpretations"][index])
				resultList.append(result)
	return resultList

"""
	Static method for populating extra info like twoFishes.

	Static so it can be called in its own thread.
"""
def processBatch(photosToProcess):
	allPhotosUpdated = list()
	
	for photos in chunks(photosToProcess, 100):
		logger.info("Starting batch of %s photos" % len(photos))
		photosToUpdate = list()
		latLonList = list()
		photosWithLL = list()
		for photo in photos:
			if photo.location_point:
				lat, lon = (photo.location_point.y, photo.location_point.x)
			else:
				lat, lon, accuracy = location_util.getLatLonAccuracyFromExtraData(photo)
				if lat and lon:
					# Something must have gone wrong at intake, lets fix it up
					photo.location_point = fromstr("POINT(%s %s)" % (lon, lat))
					photo.location_accuracy_meters = accuracy
					logger.warning("Fixed up photo %s which didn't have location point, now %s %s" % (photo.id, lon, lat))

			if lat and lon:
				latLonList.append((lat, lon))
				photosWithLL.append(photo)
			else:
				photo.twofishes_data = json.dumps({})
				photosToUpdate.append(photo)

		logger.info("Found %s lat/lon" % len(latLonList))

		twoFishesResults = getDataFromTwoFishesBulk(latLonList)

		logger.info("Got back %s results from twofishes" % len(twoFishesResults))

		for i, photo in enumerate(photosWithLL):
			city = location_util.getCity(twoFishesResults[i])
			if city:
				photo.location_city = city

			formattedResult = {"interpretations": twoFishesResults[i]}
			photo.twofishes_data = json.dumps(formattedResult)
			
			photosToUpdate.append(photo)

		logger.info("Updating %s photos" % len(photosToUpdate))
		Photo.bulkUpdate(photosToUpdate, ["twofishes_data", "location_city", "location_point", "location_accuracy_meters"])
		allPhotosUpdated.extend(photosToUpdate)
		
	return len(allPhotosUpdated)

baseQuery = Photo.objects.filter(twofishes_data=None).filter((Q(metadata__contains='{GPS}') & Q(metadata__contains='Latitude')) | Q(location_point__isnull=False))
numToProcess = 1000

@app.task
def processAll():
	return celery_helper.processBatch(baseQuery, numToProcess, processBatch)

@app.task
def processIds(ids):
	return celery_helper.processBatch(baseQuery.filter(id__in=ids), numToProcess, processBatch)



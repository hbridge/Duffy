from __future__ import absolute_import
import sys, os
import time, datetime
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.db.models import Count

from common.models import Photo, User
from arbus import similarity_util

from peanut.celery import app

from async import celery_helper
from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

def processBatch(photosToProcess):
	photosByUserId = dict()
	for photo in photosToProcess:
		if photo.user_id not in photosByUserId:
			photosByUserId[photo.user_id] = list()
		photosByUserId[photo.user_id].append(photo)

	total = 0
	for userId, photos in photosByUserId.iteritems():
		tStart = datetime.datetime.utcnow()
		logger.info("{0}: Unclustered photos: {1}".format(tStart, len(photos)))
		count = similarity_util.createSimsForPhotos(photos)
		logger.info("{0}: {1} rows added".format(datetime.datetime.utcnow()-tStart, count))
		total += count

	return total
	
baseQuery = Photo.objects.exclude(thumb_filename=None).filter(clustered_time=None).exclude(time_taken=None).order_by('time_taken')
numToProcess = 250

@app.task
def processAll():
	return celery_helper.processBatch(baseQuery, numToProcess, processBatch)
	
@app.task
def processIds(ids):
	return celery_helper.processBatch(baseQuery.filter(id_in=ids), numToProcess, processBatch)

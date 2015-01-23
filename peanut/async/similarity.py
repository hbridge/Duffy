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

from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

def chunks(l, n):
	""" Yield successive n-sized chunks from l.
	"""
	for i in xrange(0, len(l), n):
		yield l[i:i+n]

def processPhotos(photosToProcess):
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

@app.task
def processList(photoIds):
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	count = 0
	for photos in chunks(baseQuery.filter(id__in=photoIds), 250):
		processPhotos(photos)
		count += len(photos)
	return count


@app.task
def processAll():
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	count = 0
	for photos in chunks(baseQuery, 250):
		processPhotos(photos)
		count += len(photos)
	return count
#!/usr/bin/python
import sys, os
import time, datetime
import logging
import json

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.db.models import Count

from peanut import settings
from common.models import Photo, User
from arbus import face_util

logger = logging.getLogger(__name__)

def chunks(l, n):
	""" Yield successive n-sized chunks from l.
	"""
	for i in xrange(0, len(l), n):
		yield l[i:i+n]


def populateFaceData(photos, faceDetector, sizeStr):
	for photo in photos:
		if photo.faces_data:
			faceData = json.loads(photo.faces_data)
		else:
			faceData = dict()

		if "opencv" not in faceData:
			faceData["opencv"] = dict()

		if "processed" not in faceData["opencv"]:
			faceData["opencv"]["processed"] = list()
		
		rects = faceDetector.findFacesWithOpenCV(photo)
		if (len(rects) > 0):
			faceData["opencv"]["rects"] = rects
			logger.debug("Found %s for id %s" % (faceData["opencv"]["rects"], photo.id))

		faceData["opencv"]["processed"].append(sizeStr)
		
		photo.faces_data = json.dumps(faceData)

	logger.info("Writing out %s photos to db" % (len(photos)))
	Photo.bulkUpdate(photos, ["faces_data"])
		
def main(argv):
	logger.info("Starting... ")
	faceDetector = face_util.FaceDetector()
	while True:
		count = 0
		# Find all photos that have thumbs, don't have full's and don't have any face data
		nonProcessedThumbs = Photo.objects.all().filter(user__gt=75).exclude(thumb_filename=None).filter(faces_data=None).filter(full_filename=None)
		count += len(nonProcessedThumbs)
		if len(nonProcessedThumbs) > 0:
			logger.info("Found %s thumbs that need processing" % (len(nonProcessedThumbs)))
			for chunk in chunks(nonProcessedThumbs, 100):
				populateFaceData(chunk, faceDetector, "thumb")

		# Kinda hacky, looking for all photos which have a full image but don't have full face data yt
		nonProcessedFulls = Photo.objects.all().filter(user__gt=75).exclude(full_filename=None).exclude(faces_data__contains="full")
		count += len(nonProcessedFulls)
		if len(nonProcessedFulls) > 0:
			logger.info("Found %s fulls that need processing" % (len(nonProcessedFulls)))
			for chunk in chunks(nonProcessedFulls, 100):
				populateFaceData(chunk, faceDetector, "full")

		# If we didn't process anything, probably nothing being uploaded so sleep
		if count == 0:
			time.sleep(1)	

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/faces.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
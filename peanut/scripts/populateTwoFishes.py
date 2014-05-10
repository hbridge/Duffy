#!/usr/bin/python
import sys, os
import time, datetime
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.db.models import Count
from photos.models import Photo
from peanut import settings
from photos import cluster_util, location_util

def main(argv):
	logger = logging.getLogger(__name__)
	
	logger.info("Starting... ")
	while True:
		photos = Photo.objects.all().filter(twofishes_data=None).filter(metadata__contains='{GPS}')

		if len(photos) > 0:
			logger.info("Found {0} images that need two fishes data".format(len(photos)))
			location_util.populateLocationInfo(photos)

		time.sleep(1)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/twofishes.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
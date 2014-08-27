#!/usr/bin/python
import sys, os
import time, datetime
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

from django.db.models import Q

from common.models import Photo
from arbus import location_util

def main(argv):
	logger = logging.getLogger(__name__)
	
	logger.info("Starting... ")
	baseQuery = Photo.objects.all().filter(twofishes_data=None)
	while True:
		# If we have the iphone metadata or we have location_point
		photos = baseQuery.filter((Q(metadata__contains='{GPS}') & Q(metadata__contains='Latitude')) | Q(location_point__isnull=False))

		if len(photos) > 0:
			logger.info("Found {0} images that need two fishes data".format(len(photos)))
			numUpdated = location_util.populateLocationInfo(photos)
		else:
			time.sleep(1)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/twofishes.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])

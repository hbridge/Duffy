#!/usr/bin/python
import sys, os
import time, datetime
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.db.models import Count
from photos.models import Photo, User, Neighbor
from peanut import settings
from photos import cluster_util

def main(argv):
	maxFilesAtTime = 1
	logger = logging.getLogger(__name__)
	
	logger.info("Starting... ")
	while True:
		baseQuery = Photo.objects.all().exclude(user_id=1).exclude(thumb_filename=None).filter(neighbored_time=None).exclude(time_taken=None).exclude(location_point=None)[:maxFilesAtTime]

		if len(results) > 0:	
			for result in results:
				userId = result['user']
				logger.info("Processing user id:  " + str(userId))
				nonClusteredPhotos = list(baseQuery.select_related().filter(user_id=userId).order_by('time_taken')[:250])
				
				tStart = datetime.datetime.utcnow()
				logger.info("{0}: Unclustered photos: {1}".format(tStart, len(nonClusteredPhotos)))
				count = cluster_util.addToClustersBulk(nonClusteredPhotos)
				logger.info("{0}: {1} rows added".format(datetime.datetime.utcnow()-tStart, count))
		else:
			time.sleep(1)	

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/neighbor.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
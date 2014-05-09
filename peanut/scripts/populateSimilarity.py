import sys, os
import time, datetime

parentPath = os.path.abspath("..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.db.models import Count
from photos.models import Photo, User
from peanut import settings
from photos import cluster_util

def main(argv):
	print "Starting... " + time.strftime("%c")
	while True:
		results = Photo.objects.all().filter(user__gt=75).exclude(thumb_filename=None).filter(clustered_time=None).values('user').annotate(Count('user'))

		if len(results) == 0:
			print "Found no users with photos needing similarity processing at " + time.strftime("%c")
		for result in results:
			userId = result['user']
			print "Processing user id:  " + str(userId)
			nonClusteredPhotos = list(Photo.objects.select_related().filter(user_id=userId).exclude(thumb_filename=None).filter(clustered_time=None).order_by('time_taken'))
			
			tStart = datetime.datetime.utcnow()
			print("{0}: Unclustered photos: {1}".format(tStart, len(nonClusteredPhotos)))
			count = cluster_util.addToClustersBulk(nonClusteredPhotos)
			print("{0}: {1} rows added".format(datetime.datetime.utcnow()-tStart, count))
			
		time.sleep(5)

if __name__ == "__main__":
	main(sys.argv[1:])
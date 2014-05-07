import sys, os
import time

parentPath = os.path.abspath("..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from photos.models import Photo, User
from peanut import settings
from photos import cluster_util


def main(argv):
	while True:
		allUsers = User.objects.all().filter(id__gt=75) #ignores first set of accounts
		for user in allUsers:
			photos = list(Photo.objects.all().filter(user_id=user.id).exclude(thumb_filename=None).filter(clustered_time=None).order_by('time_taken'))
			print "{0}: {1} rows".format(user.id, cluster_util.addToClustersBulk(photos))
		time.sleep(5)

if __name__ == "__main__":
    main(sys.argv[1:])
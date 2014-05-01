import sys, os, getopt
import json


os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

parentPath = os.path.abspath("..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from photos.models import Photo, User, Classification, Similarity
from peanut import settings
from photos import cluster_util


def main(argv):
	if (len(sys.argv) > 1):
		userId = int(sys.argv[1])
	else:
		userId = None

	print "Starting to populate similarity table"

	allUsers = User.objects.all().filter(id__gt=38) #ignores first set of accounts
	totalRows = 0

	for user in allUsers:
		if (userId):
			if (user.id != userId):
				continue;
		photoQuery = Photo.objects.all().filter(user_id=user.id).order_by('time_taken')
		print "userId {0}: | Photos: {1}".format(user.id, photoQuery.count())

		# iterate through images
		userRows = 0
		for photo in photoQuery:
			userRows += cluster_util.addToClusters(photo.id)
		print "DB adds: {0}".format(userRows)
		totalRows += userRows
	print "Total entries generated: {0}".format(totalRows)


if __name__ == "__main__":
    main(sys.argv[1:])
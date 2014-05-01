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
		threshold = int(sys.argv[1])
	else:
		threshold = 75

	print "Starting to populate similarity table"

	allUsers = User.objects.all()
	totalRows = 0

	for user in allUsers:
		if (user.id <= 38 or user.id > 40): # ignores first set of accounts
			continue
		photoQuery = Photo.objects.all().filter(user_id=user.id).order_by('time_taken')
		print "userId {0}: | Photos: {1}".format(user.id, photoQuery.count())

		# iterate through images
		userRows = 0
		for photo in photoQuery:
			print "L: {0}, {1}".format(photo.id, photo.time_taken)
			userRows += cluster_util.addToClusters(photo.id)
		print "DB operations (added/modified): {0}".format(userRows)
		totalRows += userRows
	print "Total entries generated: {0}".format(totalRows)


if __name__ == "__main__":
    main(sys.argv[1:])
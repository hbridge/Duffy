import sys, os, getopt
import json


os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

parentPath = os.path.abspath("..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from peanut import settings

from common.models import Photo, User, Classification, Similarity
from arbus import similarity_util, image_util


def main(argv):
	if (len(sys.argv) > 1):
		userId = int(sys.argv[1])
	else:
		userId = None

	print "Starting to populate similarity table"

	allUsers = User.objects.all().filter(id__gt=38) #ignores first set of accounts

	for user in allUsers:
		if (userId and user.id != userId):
			continue;
		photoQuery = Photo.objects.all().filter(user_id=user.id).order_by('time_taken')
		print "userId {0}: | Photos: {1}".format(user.id, photoQuery.count())

		# iterate through images
		userRows = 0
		for photo in photoQuery:
			if (photo.full_filename and not photo.thumb_filename):
				image_util.createThumbnail(photo) # check in case thumbnails haven't been created

			# TODO(Derek):  This has been refactored and is probably broken now.
			similarity_util.addToClusters(photo)
		print "Done"


if __name__ == "__main__":
	main(sys.argv[1:])
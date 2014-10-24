import sys, os, getopt
import json

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut import settings

from common.models import Strand

def chunks(l, n):
	""" Yield successive n-sized chunks from l.
	"""
	for i in xrange(0, len(l), n):
		yield l[i:i+n]

def main(argv):
	if (len(sys.argv) > 1):
		userId = int(sys.argv[1])
	else:
		userId = None

	print "Starting to populate strand locations table"

	allStrands = Strand.objects.filter(location_point__isnull=True).filter(product_id=2)

	for strands in chunks(allStrands, 100):
		for strand in strands:
			for photo in strand.photos.all():
				if photo.time_taken <= strand.first_photo_time:
					strand.first_photo_time = photo.time_taken
					strand.location_point = photo.location_point
					strand.location_city = photo.location_city
					print "updated strand %s to location_city %s" % (strand.id, strand.location_city)
		

		Strand.bulkUpdate(strands, ['first_photo_time', 'location_point', 'location_city'])


if __name__ == "__main__":
	main(sys.argv[1:])
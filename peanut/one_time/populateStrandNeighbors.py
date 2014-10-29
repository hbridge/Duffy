import sys, os, getopt
import json

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut import settings

from common.models import Strand, StrandNeighbor

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

	stillGoing = True
	while stillGoing:
		strandNeighbors = StrandNeighbor.objects.select_related().filter(strand_2_private__isnull=True)[:100]

		for strandNeighbor in strandNeighbors:
			strandNeighbor.strand_1_private = strandNeighbor.strand_1.private
			strandNeighbor.strand_1_user_id = strandNeighbor.strand_1.user_id

			strandNeighbor.strand_2_private = strandNeighbor.strand_2.private
			strandNeighbor.strand_2_user_id = strandNeighbor.strand_2.user_id

			print "updating %s" % strandNeighbor.id

		if len(strandNeighbors) == 0:
			stillGoing = False
		else:
			StrandNeighbor.bulkUpdate(strandNeighbors, ['strand_1_private', 'strand_1_user_id', 'strand_2_private', 'strand_2_user_id'])


if __name__ == "__main__":
	main(sys.argv[1:])
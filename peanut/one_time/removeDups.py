import sys, os, getopt
import csv

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut import settings

from common.models import Photo, Strand

def chunks(l, n):
	""" Yield successive n-sized chunks from l.
	"""
	for i in xrange(0, len(l), n):
		yield l[i:i+n]

def main(argv):
	f = open(sys.argv[1], 'rb') # opens the csv file
	count = 0
	try:
		reader = csv.reader(f)  # creates the reader object
		photoStrandCount = dict()

		for row in reader:   # iterates the rows of the file in orders
			photos = Photo.objects.filter(user_id=int(row[0]), iphone_hash=row[1], file_key=row[2])

			for photo in photos:
				strands = Strand.photos.through.objects.filter(photo_id__in=[photo.id])
				#photoStrandCount[photo] = len(strands)
				if len(strands) == 0:
					#photo.delete()
					photo.delete()

		#for photo, count in photoStrandCount.iteritems():
			
			
	finally:
		f.close()      # closing
		

if __name__ == "__main__":
	main(sys.argv[1:])
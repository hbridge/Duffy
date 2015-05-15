import csv
import sys
import os

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.models import ZipData


def main(argv):
	f = open(sys.argv[1], 'rt')
	try:
		reader = csv.reader(f)
		for row in reader:
			ZipData.objects.create(city=row[0], state=row[1], zip_code=row[2], area_code=row[3], timezone=row[7])
			print "Created for %s" % row[2]
	finally:
		f.close()

if __name__ == "__main__":
	main(sys.argv[1:])
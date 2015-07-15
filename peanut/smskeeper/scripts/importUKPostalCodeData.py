import csv
import sys
import os

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "../..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.models import ZipData


def main(argv):
	f = open(sys.argv[1], 'rt')
	loadDataFromCSVFile(f)


def loadDataFromCSVFile(f, silent=False):
	try:
		reader = csv.reader(f)
		for row in reader:
			postalCode = row[0]
			city = row[5]
			state = row[6]
			wxcode = row[7]

			ZipData.objects.create(city=city, state=state, wxcode=wxcode, postal_code=postalCode, country_code="UK", timezone="Europe/London")
			if not silent:
				print "Created for %s" % postalCode
	finally:
		f.close()

if __name__ == "__main__":
	main(sys.argv[1:])

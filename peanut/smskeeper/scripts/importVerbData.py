import csv
import sys
import os

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "../..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.models import VerbData


def main(argv):
	f = open(sys.argv[1], 'rt')
	try:
		reader = csv.reader(f)
		for row in reader:
			if row[0] != "id":  # skip header row
				VerbData.objects.create(base=row[1], past=row[2], past_participle=row[3], s_es_ies=row[4], ing=row[5])
				print "Created for %s" % row[1]
	finally:
		f.close()

if __name__ == "__main__":
	main(sys.argv[1:])

#!/usr/bin/python
import sys, os, requests, json
import pytz
import logging
from datetime import datetime, date, timedelta
from dateutil.relativedelta import relativedelta

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut.settings import constants
from common.models import User, FriendConnection, Action, Photo, StrandNeighbor, Strand

from django.db.models import Count, Sum

# This script remove duplicate private strands
def main(argv):
	print 'Starting...'

	now = datetime.utcnow().replace(tzinfo=pytz.utc)
	td = timedelta(days=7)

	#strands = Strand.photos.through().aggregate(totalPhotos=Count('photo_id'))

	strands = Strand.objects.prefetch_related('photos').filter(added__gt=now-td)

	print "%s found"%(len(strands))
	photoToStrandDict = dict()

	for strand in strands:
		for photo in strand.photos.all():
			if photo.id in photoToStrandDict:
				photoToStrandDict[photo.id].append(strand)
			else:
				photoToStrandDict[photo.id] = [strand]

	strandsToDelete = set()
	for k, i in photoToStrandDict.items():
		if len(i) > 1:
			strandsToDelete.add(i[0])
			print "%s: %s"%(k, i)

	for s in strandsToDelete:
		print "Deleting strand ids: %s"%(s)
		#s.delete() #uncomment this to actually do delete
	print "%s strands to delete"%(len(strandsToDelete))
	print 'Finished...'
		
if __name__ == "__main__":

	main(sys.argv[1:])
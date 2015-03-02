#!/usr/bin/python
import sys, os, requests, json
import pytz
import logging
import datetime
from dateutil.relativedelta import relativedelta

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut.settings import constants
from common.models import User, FriendConnection, Action, Photo, StrandNeighbor, Strand, ShareInstance

from django.db.models import Count, Sum

from async import stranding


# This script remove duplicate private strands
def main(argv):
	print 'Starting...'

	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	delta = datetime.timedelta(weeks=2)
	shareInstances = ShareInstance.objects.filter(added__gt=(now-delta)).prefetch_related('photo')

	totalShareInstances = 0
	totalStrands = 0
	totalPhotos = 0

	strandPhotoShareCounts = dict()
	for shareInstance in shareInstances:
		strands = shareInstance.photo.strand_set.filter(private=True)
		for strand in strands:
			print "For share instance: %s  photo id: %s  strand: %s" % (shareInstance.id, shareInstance.photo_id, strand.id)
			if strand not in strandPhotoShareCounts:
				strandPhotoShareCounts[strand] = 0
			strandPhotoShareCounts[strand] += 1

	shareCounts = dict()
	blah = dict()
	for strand, count in strandPhotoShareCounts.iteritems():
		photoCount = len(strand.photos.all())
		print "%s %s %s" % (strand.id, count, photoCount)
		if count not in shareCounts:
			shareCounts[count] = 0

		shareCounts[count] += 1

		if count not in blah:
			blah[count] = dict()
		if photoCount not in blah[count]:
			blah[count][photoCount] = 0
		blah[count][photoCount] += 1

	for key, value in shareCounts.iteritems():
		print "%s %s" % (key, value)

	for key, value in blah.iteritems():
		print "For strands that had %s photos shared:" % (key)
		for a, b in value.iteritems():
			print "%s times the strand had %s photos" % (b, a)



	print 'Finished...'
		
if __name__ == "__main__":

	main(sys.argv[1:])
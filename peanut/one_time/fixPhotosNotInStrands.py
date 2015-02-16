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

from async import stranding


# This script remove duplicate private strands
def main(argv):
	print 'Starting...'

	now = datetime.utcnow().replace(tzinfo=pytz.utc)
	

	userId = 5024
	user = User.objects.get(id=userId)
	users = [user]
	#users = User.objects.filter(product_id=2)
	
	for user in users:
		photos = Photo.objects.filter(user=user).filter(is_dup=False).filter(install_num__gt=-1)
		strands = Strand.objects.filter(user=user).filter(private=True)

		strandByPhotoId = dict()
		for strand in strands:
			for photo in strand.photos.all():
				if photo.id in strandByPhotoId:
					print "ERROR:  found photo %s already in strand %s and also %s" % (photo.id, strandByPhotoId[photo.id].id, strand.id)
				else:
					strandByPhotoId[photo.id] = strand

		photosToSave = list()
		for photo in photos:
			if photo.id not in strandByPhotoId:
				print "Found photo %s not in a strand" % (photo.id)
				photo.strand_evaluated = False

				if not photo.product_id and photo.install_num == user.install_num:
					print "found photo %s without product_id" % (photo.id)
					#photo.product_id = 2
				photosToSave.append(photo)
		
		if len(photosToSave) > 0:
			Photo.bulkUpdate(photosToSave, ["strand_evaluated", "product_id"])
			stranding.processIds.delay(Photo.getIds(photosToSave))
			print "processed %s photos for user %s" % (len(photosToSave), user.id)

	print 'Finished...'
		
if __name__ == "__main__":

	main(sys.argv[1:])
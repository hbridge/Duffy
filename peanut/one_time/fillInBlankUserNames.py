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
from common.models import User, FriendConnection, Action, Photo, StrandNeighbor, Strand, ContactEntry

from django.db.models import Count, Sum

from async import stranding


# This script remove duplicate private strands
def main(argv):
	print 'Starting...'

	now = datetime.utcnow().replace(tzinfo=pytz.utc)
	
	users = User.objects.filter(display_name="")

	for user in users:
		entries = ContactEntry.objects.filter(phone_number=user.phone_number)
		bestName = None
		for entry in entries:
			firstName = entry.name.split(' ')[0]

			print "Found phone entry of %s for user %s" % (firstName, user.id)
	print 'Finished...'
		
if __name__ == "__main__":

	main(sys.argv[1:])
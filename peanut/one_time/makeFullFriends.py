#!/usr/bin/python
import sys, os, requests, json
import pytz
import logging
from datetime import datetime, date, timedelta
from dateutil.relativedelta import relativedelta
import gdata.spreadsheet.service

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.core.mail import EmailMessage, EmailMultiAlternatives
from django.db.models import Count, Sum
from django.db.models import Q

from peanut.settings import constants
from common.models import User, FriendConnection, Action, Photo, StrandNeighbor


# Makes everyone before id 2628 in friends table
def main(argv):
	print 'Starting...'

	friendConnections = FriendConnection.objects.all()

	print "%s friendConnections found"%(len(friendConnections))

	toBeUpdatedCount = 0
	actualUpdatedCount = 0
	for fc in friendConnections:
		if fc.id <= 2628:
			toBeUpdatedCount += 1
			#if FriendConnection.friendReverseConnectionExists(fc.user_1, fc.user_2, friendConnections):
			if FriendConnection.addReverseConnection(fc.user_1, fc.user_2):
				actualUpdatedCount += 1

	print "TobeUpdated: %s"%(toBeUpdatedCount)
	print "ActualUpdated: %s"%(actualUpdatedCount)

		
if __name__ == "__main__":

	main(sys.argv[1:])
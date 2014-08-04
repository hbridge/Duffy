#!/usr/bin/python
import sys, os
import time, datetime
import logging
import math
import pytz

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

from django.db.models import Count

from peanut.settings import constants
from common.models import Photo, Strand, User

from strand import geo_util
import strand.notifications_util as notifications_util


def hasFounderOrTest(users):
	for user in users:
		if user.phone_number:
			if str(user.phone_number) in constants.DEV_PHONE_NUMBERS:
				return True
			if "555555" in str(user.phone_number):
				return True

	return False
"""
	Grab all photos that are not strandEvaluated and grab all strands from the last 24 hours
	for each photo, go through each strand and see if it fits the requirements
	If a photo meets requirements for two or more strands, then merge them.

	Requirements right now are that the photo is within 3 hours of any photo in a strand and within 100 meters of a photo

	TODO(Derek): Right now we're using Django's object model to deal with the strand connection mappings.  This is slow since it
	writes a new row for each loop.  Would be faster to manually write the table entries in a batch call
"""
def main(argv):
	strands = Strand.objects.all()
	soloCount = 0
	noPhotoUsers = list()
	soloUsers = list()
	nonSoloUsers = list()
	nonFounderUsers = list()
	usersInStrandWithFounder = list()
	usersNeverWithFounder = list()

	userStats = User.objects.filter(product_id=1).annotate(totalCount=Count('photo'))

	for i, user in enumerate(userStats):
		if user.totalCount == 0:
			noPhotoUsers.append(user)

	for strand in strands:
		users = strand.users.all()
		if len(users) == 1:
			soloCount+=1
			soloUsers.append(users[0])
		elif len(users) > 1:
			nonSoloUsers.extend(users)

			if not hasFounderOrTest(users):
				nonFounderUsers.extend(users)
			else:
				usersInStrandWithFounder.extend(users)


	soloUsers = set(soloUsers)
	nonSoloUsers = set(nonSoloUsers)
	nonFounderUsers = set(nonFounderUsers)

	for nonSoloUser in nonSoloUsers:
		soloUsers = filter(lambda user: user.id != nonSoloUser.id, soloUsers)

	usersNeverWithFounder = nonFounderUsers
	for connectedToFounderUser in usersInStrandWithFounder:
		usersNeverWithFounder = filter(lambda user: user.id != connectedToFounderUser.id, usersNeverWithFounder)		

	nonFounderUsers = filter(lambda user: user.phone_number, nonFounderUsers)
	usersNeverWithFounder = filter(lambda user: user.phone_number, usersNeverWithFounder)

	print "Total users: %s" % (len(userStats))

	print "Total users with 0 photos: %s" % (len(noPhotoUsers))
	for user in noPhotoUsers:
		print user

	print ""
	print ""
	print "%s users that are only in strands by themselves" % (len(soloUsers))
	for user in soloUsers:
		print user

	print ""
	print ""
	
	print "%s users have strands with non founders" % (len(nonFounderUsers))
	for user in nonFounderUsers:
		print user
	

	print ""
	print ""
	
	print "%s users have strands no strands with any founders" % (len(usersNeverWithFounder))
	for user in usersNeverWithFounder:
		print user



if __name__ == "__main__":
	main(sys.argv[1:])
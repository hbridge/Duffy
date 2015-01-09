#!/usr/bin/python
import sys, os
import time, datetime
import pytz
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.db.models import Count
from django.db.models import Q

from peanut.settings import constants
from common.models import Action, Photo, StrandNeighbor

from strand import notifications_util, geo_util, strands_util, friends_util

logger = logging.getLogger(__name__)


def sendRetroFirestarterNotification():
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	timeWithin = now - datetime.timedelta(days=4)

	notificationLogs = notifications_util.getNotificationLogs(timeWithin)
	notificationsById = notifications_util.getNotificationsForTypeByIds(notificationLogs, [constants.NOTIFICATIONS_RETRO_FIRESTARTER])

	recentPhotos = Photo.objects.filter(strand_evaluated=True).filter(time_taken__gt=timeWithin)

	users = set([recentPhoto.user for recentPhoto in recentPhotos])

	for user in users:
		friendsIds = friends_util.getFriendsIds(user.id)

		# Get all neighbor rows for this user from the last 3 days
		neighbors = StrandNeighbor.objects.prefetch_related('strand_1__photos', 'strand_2__photos').filter((Q(strand_1_user_id=user.id) & Q(strand_2_user_id__in=friendsIds)) | (Q(strand_2_user_id=user.id) & Q(strand_1_user_id__in=friendsIds))).filter(strand_1__first_photo_time__gt=timeWithin).filter(strand_1__last_photo_time__lt=(now - constants.TIMEDELTA_FOR_STRANDING))

		neighborsByStrand = dict()

		for neighbor in neighbors:
			if neighbor.strand_1_user_id == user.id:
				otherStrand = neighbor.strand_2
				myStrand = neighbor.strand_1
			else:
				otherStrand = neighbor.strand_1
				myStrand = neighbor.strand_2

			if myStrand and otherStrand:
				if (not myStrand.contributed_to_id and myStrand.suggestible and myStrand.location_point and 
					not otherStrand.contributed_to_id and otherStrand.suggestible and otherStrand.location_point):
					if myStrand not in neighborsByStrand:
						neighborsByStrand[myStrand] = list()
					neighborsByStrand[myStrand].append(otherStrand)

		winningStrand = None
		winningCount = 0
		for strand, neighborStrands in neighborsByStrand.iteritems():
			myStrandPhotos = strand.photos.all()
			allOtherPhotos = list()
			for neighborStrand in neighborStrands:
				allOtherPhotos.extend(neighborStrand.photos.all())


			if len(myStrandPhotos) > 1 and len(allOtherPhotos) > 1:
				if (not winningStrand or len(myStrandPhotos) + len(allOtherPhotos) > winningCount):
					winningStrand = strand
					winningCount = len(myStrandPhotos) + len(allOtherPhotos)

		if winningStrand:
			users = list()
			[users.extend(s.users.all()) for s in neighborsByStrand[winningStrand]]
			
			usersNames = [u.display_name for u in users]
			usersStr = ', '.join(usersNames)
			msg = "You have %s photos to swap with %s from this weekend" % (len(winningStrand.photos.all()), usersStr)
			
			customPayload = {'id': myStrand.id}
			print "to %s: %s   id: %s" % (user.display_name, msg, myStrand.id)
			
			#notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_RETRO_FIRESTARTER, customPayload)

def main(argv):
	logger.info("Starting... ")
	

	sendRetroFirestarterNotification()
		
	print "Done"
		
if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
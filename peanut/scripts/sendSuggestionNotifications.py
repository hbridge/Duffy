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
from django.db.models import Q, F

from peanut.settings import constants
from common.models import Photo, NotificationLog, User, Strand

from strand import notifications_util, friends_util, swaps_util

logger = logging.getLogger(__name__)


def sendSuggestionNotification(user, interestedUsersByStrandId, matchReasonsByStrandId, strands):
	photoCount = 0
	userNames = set()
	photosToUpdate = list()

	for strand in strands:
		# TODO: add a check for right reason (location-user or location-strand)
		for intUser in interestedUsersByStrandId[strand.id]:
			userNames.add(intUser.display_name.split(' ', 1)[0])

		# fetch all photos in this strand that have notification_sent = null
		photos = strand.photos.filter(notification_sent__isnull=True)
		for photo in photos:
			photo.notification_evaluated = True
			photo.notification_sent = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		photoCount += len(photos)
		photosToUpdate.extend(photos)

	photoPhrase, userPhrase = listsToPhrases(photoCount, userNames)

	msg = "Send your recent %s to %s in Swap"%(photoPhrase, userPhrase)

	logger.debug("going to send '%s' to user id %s" % (msg, user.id))
	customPayload = {}
	notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_NEW_SUGGESTION, customPayload)

	return photosToUpdate


def listsToPhrases(photoCount, userNames):

	if (photoCount == 0):
		return '',''
	elif (photoCount == 1):
		photoPhrase = "photo"
	elif (photoCount > 1):
		photoPhrase = "photos"

	if (len(userNames) > 0):
		userNames = list(userNames)
	else:
		userNames = list()

	if len(userNames) == 1:
		userPhrase = userNames[0]
	elif len(userNames) == 2:
		userPhrase = userNames[0] + " and " + userNames[1]
	elif len(userNames) > 2:
		userPhrase = userNames[0] + ", " + userNames[1] + " and %s others"%(len(userNames)-2)
	else:
		logger.error("No usernames found!")
		return None
	
	return (photoPhrase, userPhrase)

def main(argv):
	logger.info("Starting... ")
	photoTimedelta = datetime.timedelta(minutes=720)
	notificationTimedelta = datetime.timedelta(seconds=constants.NOTIFICATIONS_NEW_SUGGESTIONS_INTERVAL_SECS)

	while True:
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)

		# get all recent unevaluated photos that have already been stranded
		# TODO: known bug. If a user is invited and doesn't join soon after, this query (F('user_added'))
		# will suggest photos from the time the user was invited, not when he/she actually signed up.
		photos = Photo.objects.filter(time_taken__gt=now-photoTimedelta).filter(strand_evaluated=True).filter(notification_evaluated=False).filter(time_taken__gt=F('user__added'))
		photosToUpdate = list()

		# get all their strands.
		strands = Strand.objects.prefetch_related('photos').filter(private=True).filter(photos__in=[photo.id for photo in photos]).distinct() #filter(photos__notification_sent__isnull=True).distinct()

		strandsByUser = dict()
		for strand in strands:
			if strand.user in strandsByUser:
				if strand not in strandsByUser[strand.user]: # to handle duplicate strands
					strandsByUser[strand.user].append(strand)
			else:
				strandsByUser[strand.user] = [strand]

		# get all the suggestions sent out in the last 60 sec and don't send to those users
		recentUsersNotified = NotificationLog.objects.filter(msg_type=constants.NOTIFICATIONS_NEW_SUGGESTION).filter(result=constants.IOS_NOTIFICATIONS_RESULT_SENT).filter(added__gt=now-notificationTimedelta).values('user').distinct()
		recentUsersNotifiedList = list()

		for entry in recentUsersNotified:
			recentUsersNotifiedList.append(entry['user'])

		for user, recentStrands in strandsByUser.items():
			if user.id in recentUsersNotified:
				logger.info("Skipping user %s because we sent suggestions recently")%(user.id)
				continue
			interestedUsersByStrandId, matchReasonsByStrandId, strands = swaps_util.getInterestedUsersForStrands(user, recentStrands, True, friends_util.getFriends(user.id))

			if len(strands) == 0:
				# means no match found, mark all the photos in these strands as notification_evaluated
				for strand in recentStrands:
					for photo in strand.photos.filter(notification_evaluated=False):
						photo.notification_evaluated=True
						photosToUpdate.append(photo)
			else:
				photosToUpdate.extend(sendSuggestionNotification(user, interestedUsersByStrandId, matchReasonsByStrandId, strands))

		if len(photosToUpdate) > 0:
			Photo.bulkUpdate(photosToUpdate, ['notification_evaluated', 'notification_sent'])

		time.sleep(1)

		
if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/suggestion-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
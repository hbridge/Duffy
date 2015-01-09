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
from common.models import Action, StrandInvite, Photo, NotificationLog, User, ShareInstance

from strand import notifications_util, friends_util

logger = logging.getLogger(__name__)


def sendSummaryFirestarterText(msgCount=10, testRun=True):
	sentCount = 0
	url = 'bit.ly/openswap'

	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	start = now - datetime.timedelta(days=7)
	end = now - datetime.timedelta(days=0)

	# fetch all the users who have been sent this firestarter in the last week 
	logEntries = NotificationLog.objects.prefetch_related('user').filter(added__gt=start).filter(msg_type=constants.NOTIFICATIONS_UNACCEPTED_INVITE_FS)

	# Convert that into a list
	phoneNumList = list()
	for logEntry in logEntries:
		if logEntry.phone_number:
			phoneNumList.append(str(logEntry.phone_number))
		else:
			phoneNumList.append(str(logEntry.user.phone_number))

	# fetch all shareInstances from last week that were uploaded
	shareInstances = ShareInstance.objects.prefetch_related('users').filter(shared_at_timestamp__gt=start).filter(shared_at_timestamp__lt=end).exclude(photo__full_filename__isnull=True)

	# fetch all actions for last 7-days that are photo_evaluated and associated with above shareInstances
	# Note this doesn't need an end filter, since actions after 7-day cutoff should still be counted.
	actions = Action.objects.prefetch_related('user').filter(added__gt=start).filter(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED).filter(share_instance__in=[si.id for si in shareInstances])

	# Create a dict to access all actions by a user fast
	actionsByUser = dict()
	for action in actions:
		if action.user_id in actionsByUser:
			actionsByUser[action.user_id].append(action)
		else:
			actionsByUser[action.user_id] = [action]

	# use this to store all the users and their unseen photos
	incomingListByUser = dict()

	# for each shareInstance, for each user, find the photo_evaluated action for that SI
	# If not found, add to incomingListByUser 
	for si in shareInstances:
		for user in si.users.all():
			if si.user != user:
				siEvaluated = False
				if user.id in actionsByUser:
					for action in actionsByUser[user.id]:
						if action.photo == si.photo:
							siEvaluated = True
				if not siEvaluated and str(user.phone_number) not in phoneNumList:
					if user in incomingListByUser:
						incomingListByUser[user].append(si)
					else:
						incomingListByUser[user] = [si]


	for user, siList in incomingListByUser.items():
		if msgCount == 0:
			break

		photoPhrase, userPhrase = listsToPhrases(siList, friends_util.getFriendsIds(user.id))

		if photoPhrase == '':
			# No photos were found, skip
			continue

		# generate the message
		msg = "You have %s %s waiting for you in Swap" % (photoPhrase, userPhrase)
		sentCount+= 1
		msgCount -= 1		

		# Check to see if we have a deviceToken so we can send a push notification
		if user.device_token:
			deviceToken = True
			print "To %s (device_token - %s): \t\t%s" % (user.display_name, deviceToken, msg)
		else:
			deviceToken = False
			print "To %s (%s): \t\t%s %s" % (user.display_name, user.phone_number, msg, url)

		# If not testRun, send a real message to user and record it
		if (not testRun and user.has_sms_authed):
			logEntry = notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_UNACCEPTED_INVITE_FS, {}, None)
			if (logEntry[0].result == constants.IOS_NOTIFICATIONS_RESULT_ERROR):
				# meaning couldn't send notification, so send a text
				if (not '555555' in str(user.phone_number)):
					notifications_util.sendSMS(str(user.phone_number), msg + ' ' + url)
					logger.debug("SMS sent to %s: %s %s" % (user, msg, url))
					print "SMS sent"
				else:
					logger.debug("Nothing sent to %s: %s" % (user, msg))
			else:
				logger.debug("Push notification sent to %s: %s" % (user, msg))
				print "Push notification sent"


	return sentCount

def listsToPhrases(siList, friendList):
	photoCount = len(siList)
	userNames = set()
	
	photoPhrase = ""
	if (photoCount == 1):
		photoPhrase = "%s photo" % (photoCount)
	elif (photoCount > 1):
		photoPhrase = "%s photos" % (photoCount)

	for si in siList:
		if si.user.id in friendList:
			userNames.add(si.user.display_name.split(' ', 1)[0])
		else:
			for user in si.users.all():
				if user.id in friendList:
					userNames.add(user.display_name.split(' ', 1)[0])


	userPhrase = ""
	userNames = list(userNames)
	if len(userNames) == 0:
		userPhrase = ''
	if len(userNames) == 1:
		userPhrase = 'from ' + userNames[0]
	elif len(userNames) == 2:
		userPhrase = "from " + userNames[0] + " and " + userNames[1]
	elif len(userNames) > 2:
		userPhrase = "from " + ', '.join(userNames[:-1]) + ', and ' + userNames[-1]
	
	return (photoPhrase, userPhrase)


def main(argv):
	logger.info("Starting... ")
	
	isTestRun = True

	if (len(argv) > 0):
		if (argv[0] == 'sendnow'):
			isTestRun = False

	msgCount = sendSummaryFirestarterText(10, isTestRun)
	
	if (isTestRun):
		print "\nFinished test run: %s messages generated" % (msgCount)
		print "Pro tip: 'python scripts/sendSummaryFirestarterText sendnow' to send out messages for real!\n"
	else:
		print "\nFinished REAL run: %s msgs sent!" % (msgCount)
		
if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
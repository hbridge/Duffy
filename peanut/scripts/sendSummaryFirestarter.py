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
from common.models import Action, StrandInvite, Photo, NotificationLog, User

from strand import notifications_util

logger = logging.getLogger(__name__)


def sendSummaryFirestarterText(msgCount=10, testRun=True):
	sentCount = 0
	url = 'http://bit.ly/swap-beta'

	# find users in the last n-days that have an unaccepted invite
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	timeWithin = now - datetime.timedelta(days=7)

	# fetch all the users who have been sent an invite in the last week 
	logEntries = NotificationLog.objects.prefetch_related('user').filter(added__gt=timeWithin).filter(msg_type=constants.NOTIFICATIONS_UNACCEPTED_INVITE_FS)

	# Convert that into a list
	phoneNumList = list()
	for logEntry in logEntries:
		if logEntry.phone_number:
			phoneNumList.append(str(logEntry.phone_number))
		else:
			phoneNumList.append(str(logEntry.user.phone_number))

	invites = StrandInvite.objects.prefetch_related('strand', 'user', 'invited_user').filter(accepted_user_id=None).filter(added__gt=timeWithin).filter(added__lt=now-datetime.timedelta(days=1))

	userToInvitesDict = dict()
	for invite in invites:
		# if the user joined in the last 24 hours, don't send them anything
		if (invite.phone_number in phoneNumList or 
			(invite.invited_user == None) or # skipping non-signed up users for now
			(invite.invited_user and invite.invited_user.added > now - datetime.timedelta(days=1))):
			continue
		if invite.phone_number in userToInvitesDict:
			userToInvitesDict[invite.phone_number].append(invite)
		else:
			userToInvitesDict[invite.phone_number] = [invite]

	for key, entry in userToInvitesDict.items():
		if (msgCount == 0):
			break;

		actionList = Action.objects.prefetch_related('photos').filter(strand__in=[invite.strand for invite in entry], 
			user__in=[invite.user for invite in entry], action_type=constants.ACTION_TYPE_CREATE_STRAND).order_by('-added')

		(photoPhrase, userPhrase) = listsToPhrases(entry, actionList)
		if (photoPhrase == ""):
			# no photos were found, so need to send a reminder
			continue

		# generate the message
		msg = "You have %s from %s waiting for you in Swap" % (photoPhrase, userPhrase)
		msgCount-=1
		sentCount+=1

		# Check to see if we have a deviceToken so we can send a push notification
		if (entry[0].invited_user_id):
			if (entry[0].invited_user.device_token):
				deviceToken = True
			else:
				deviceToken = False
			print "To %s (device_token - %s): \t\t%s" % (entry[0].invited_user.display_name, deviceToken, msg)

		else:
			print "To %s: \t\t%s %s" % (entry[0].phone_number, msg, url)

		# If not testRun, send a real message to user and record it
		if (not testRun):
			if (invite.invited_user):
				logEntry = notifications_util.sendNotification(invite.invited_user, msg, constants.NOTIFICATIONS_UNACCEPTED_INVITE_FS, {}, None)
			else:
				logEntry = NotificationLog.objects.create(phone_number=invite.phone_number, device_token="", msg=msg, custom_payload="", result=constants.IOS_NOTIFICATIONS_RESULT_ERROR, msg_type=constants.NOTIFICATIONS_UNACCEPTED_INVITE_FS)

			if (logEntry[0].result == constants.IOS_NOTIFICATIONS_RESULT_ERROR):
				# meaning couldn't send notification, so send a text
				if (not '555555' in str(invite.user.phone_number) and not '555555' in str(invite.invited_user.phone_number)):
					notifications_util.sendSMS(invite.phone_number, msg)
					logger.debug("SMS sent to %s: %s %s" % (invite.invited_user, msg, url))
					print "SMS sent"
				else:
					logger.debug("Nothing sent to %s: %s" % (invite.invited_user, msg))
			else:
				logger.debug("Push notification sent to %s: %s" % (invite.invited_user, msg))
				print "Push notification sent"


	return sentCount

def listsToPhrases(inviteList, actionList):
	photoCount = 0
	userNames = set()

	for action in actionList:
		photoCount += action.photos.count()
	
	photoPhrase = ""
	if (photoCount == 1):
		photoPhrase = "%s photo" % (photoCount)
	elif (photoCount > 1):
		photoPhrase = "%s photos" % (photoCount)

	for invite in inviteList:
		userNames.add(invite.user.display_name.split(' ', 1)[0])

	userPhrase = ""
	userNames = list(userNames)
	if len(userNames) == 1:
		userPhrase = userNames[0]
	elif len(userNames) == 2:
		userPhrase = userNames[0] + " and " + userNames[1]
	elif len(userNames) > 2:
		userPhrase = ', '.join(userNames[:-1]) + ', and ' + userNames[-1]
	
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
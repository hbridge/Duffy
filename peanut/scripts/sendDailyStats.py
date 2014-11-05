#!/usr/bin/python
import sys, os
import pytz
import logging
from datetime import datetime, date, timedelta
from dateutil.relativedelta import relativedelta

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.core.mail import send_mail
from django.db.models import Count, Sum
from django.db.models import Q

from peanut.settings import constants
from common.models import User, FriendConnection, Action, StrandInvite, Photo, StrandNeighbor

logger = logging.getLogger(__name__)

def compileStats():
	'''
		Subject: Daily Stats
		
		--- USERS ---
		Active users:
		New Users:
		New Friends: 
		
		--- PHOTOS ---
		Photos Uploaded:
		Photos Shared: 

		--- ACTIONS ---
		Swaps Created: 
		Swaps Joined:
		Photos Added:
		Favorites:

	'''

	# figure out time window
	tzinfo = pytz.timezone('US/Eastern')
	beginTime = datetime.today().replace(tzinfo=tzinfo, hour=0, minute=0, second=0)-relativedelta(days=1)
	endTime = beginTime+relativedelta(days=1)

	#generate emailBody
	msg = "\nStats for " + beginTime.strftime('%m/%d/%Y') + "\n"

	msg += compileUserStats(beginTime)
	msg += compilePhotosStats(beginTime)
	msg += compileActionStats(beginTime)	

	return msg

def compileUserStats(date, length=1):

	msg = "\n--- USERS ---\n"

	activeUsers = Action.objects.values('user').filter(added__gt=date).filter(added__lt=date+relativedelta(days=length)).distinct().count()
	msg += "Active Users: " + str(activeUsers) + "\n"

	newUsers = User.objects.filter(product_id=2).filter(added__gt=date).filter(added__lt=date+relativedelta(days=length)).count()
	msg += "New Users: " + str(newUsers) + "\n"

	newFriends = FriendConnection.objects.filter(added__gt=date).filter(added__lt=date+relativedelta(days=length)).count()
	msg += "New Friends: " + str(newFriends) + "\n"

	return msg

def compilePhotosStats(date, length=1):

	msg = "\n--- PHOTOS ---\n"

	newPhotosUploaded = Photo.objects.filter(added__gt=date).filter(added__lt=date+relativedelta(days=length)).count()
	msg += "Photos Uploaded: " + format(newPhotosUploaded, ",d") + "\n"

	newPhotosShared = Action.objects.prefetch_related('photos').filter(added__gt=date).filter(added__lt=date+relativedelta(days=length)).annotate(totalPhotos=Count('photos')).aggregate(Sum('totalPhotos'))
	msg += "Photos Shared: " + format(newPhotosShared['totalPhotos__sum'], ",d") + "\n"

	return msg

def compileActionStats(date, length=1):

	msg = "\n--- ACTIONS ---\n"

	actionTypeCounts = Action.objects.values('action_type').filter(added__gt=date).filter(added__lt=date+relativedelta(days=length)).annotate(totals=Sum('action_type'))

	for entry in actionTypeCounts:
		if (entry['action_type'] == constants.ACTION_TYPE_CREATE_STRAND):
			msg += "Swaps Created: " + str(entry['totals']) + '\n'
		elif (entry['action_type'] == constants.ACTION_TYPE_JOIN_STRAND):
			msg += "Swaps Joined: " + str(entry['totals']) + '\n'	
		elif (entry['action_type'] == constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND):
			msg += "Photos Added: " + str(entry['totals']) + '\n'	
		elif (entry['action_type'] == constants.ACTION_TYPE_FAVORITE):
			msg += "Favorites: " + str(entry['totals']) + '\n'	

	return msg


def main(argv):
	logger.info("Starting... ")

	emailSubj = 'Daily Stats'
	emailBody = compileStats()

	print emailBody


	send_mail(emailSubj, emailBody, 'prod@duffyapp.com', ['swap-stats@duffytech.co'], fail_silently=False)
		
		
if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
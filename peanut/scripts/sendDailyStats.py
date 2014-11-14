#!/usr/bin/python
import sys, os
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

from django.core.mail import EmailMessage
from django.db.models import Count, Sum
from django.db.models import Q

from peanut.settings import constants
from common.models import User, FriendConnection, Action, StrandInvite, Photo, StrandNeighbor

logger = logging.getLogger(__name__)

def compileData(date, length):

	'''
		Subject: Daily Stats
		
		--- USERS ---
		Active users:
		New Users:
		New Friends: 
		Check-ins:
		
		--- PHOTOS (OLD USERS) ---
		Photos Uploaded:		
		Photos Shared: 

		--- PHOTOS (NEW USERS) ---
		Photos Uploaded:		
		Photos Shared: 

		--- ACTIONS (OLD USERS) ---
		Swaps Created: 
		Swaps Joined:
		Photos Added:
		Favorites:
		Comments:

		--- ACTIONS (NEW USERS) ---
		Swaps Created: 
		Swaps Joined:
		Photos Added:
		Favorites:
		Comments:

	'''

	newUsers = getNewUsers(date, length)
	dataDictDate = {'date': (date-relativedelta(days=1)).strftime('%m/%d/%Y')}
	dataDictUsers = getUserStats(date, length, newUsers)
	dataDictPhotos = getPhotoStats(date, length, newUsers)
	dataDictActions = getActionStats(date, length, newUsers)

	return dict(dataDictDate.items() + dataDictUsers.items() + dataDictPhotos.items() + dataDictActions.items())

def getNewUsers(date, length):
	newUsers = User.objects.filter(product_id=2).filter(added__lt=date).filter(added__gt=date-relativedelta(days=length))
	return newUsers

def getUserStats(date, length, newUsers):

	activeUsers = Action.objects.values('user').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).distinct().count()
	newUsers = newUsers.count()
	newFriends = FriendConnection.objects.filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).count()
	checkIns = User.objects.filter(last_photo_update_timestamp__lt=date).filter(last_photo_update_timestamp__gt=date-relativedelta(days=length)).count()

	# note that gdata api requires that dictionary keys be all lowercase and no spaces
	return {'ActiveUsers': activeUsers,
			'NewUsers': newUsers, 
			'NewFriends': newFriends, 
			'CheckIns': checkIns}


def getPhotoStats(date, length, newUsers):

	# Old users
	newPhotosUploadedOldUsers = Photo.objects.filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).exclude(user__in=newUsers).count()
	newPhotosSharedOldUsers = Action.objects.prefetch_related('photos').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).exclude(user__in=newUsers).annotate(totalPhotos=Count('photos')).aggregate(Sum('totalPhotos'))['totalPhotos__sum']
	if newPhotosSharedOldUsers == None:
		newPhotosSharedOldUsers = 0

	# new users
	newPhotosUploadedNewUsers = Photo.objects.filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).filter(user__in=newUsers).count()
	newPhotosSharedNewUsers = Action.objects.prefetch_related('photos').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).filter(user__in=newUsers).annotate(totalPhotos=Count('photos')).aggregate(Sum('totalPhotos'))['totalPhotos__sum']
	if newPhotosSharedNewUsers == None:
		newPhotosSharedNewUsers = 0

	# note that gdata api requires that dictionary keys be all lowercase and no spaces
	return {'PhotosUploadedOldUsers': newPhotosUploadedOldUsers,
			'PhotosSharedOldUsers': newPhotosSharedOldUsers,
			'PhotosUploadedNewUsers': newPhotosUploadedNewUsers,
			'PhotosSharedNewUsers': newPhotosSharedNewUsers}


def getActionStats(date, length, newUsers):

	dataDict = {}

	# old users
	actionTypeCounts = Action.objects.values('action_type').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).exclude(user__in=newUsers).annotate(totals=Count('action_type'))

	dataDict['SwapsCreatedOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_CREATE_STRAND)
	dataDict['SwapsJoinedOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_JOIN_STRAND)
	dataDict['PhotosAddedOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND)
	dataDict['FavsOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_FAVORITE)
	dataDict['CommentsOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_COMMENT)

	# new users
	actionTypeCounts = Action.objects.values('action_type').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).filter(user__in=newUsers).annotate(totals=Count('action_type'))

	dataDict['SwapsCreatedNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_CREATE_STRAND)
	dataDict['SwapsJoinedNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_JOIN_STRAND)
	dataDict['PhotosAddedNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND)
	dataDict['FavsNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_FAVORITE)
	dataDict['CommentsNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_COMMENT)


	return dataDict

def actionStatsHelper(actionTypeCounts, actionType):
	for entry in actionTypeCounts:
		if (entry['action_type'] == actionType):
			return entry['totals']
	return 0

def dataDictToString(dataDict, length):

	msg = "\n" + str(length) + "-day stats for " + dataDict['date'] + "\n"

	# users	
	msg += "\n--- USERS ---\n"
	msg += "Active Users: " + str(dataDict['ActiveUsers']) + "\n"
	msg += "New Users: " + str(dataDict['NewUsers']) + "\n"
	msg += "New Friends: " + str(dataDict['NewFriends']) + "\n"
	msg += "Check-ins: " + str(dataDict['CheckIns']) + "\n"

	# photos, old users
	msg += "\n--- PHOTOS (OLD USERS) ---\n"
	msg += "Photos Uploaded: " + format(dataDict['PhotosUploadedOldUsers'], ",d") + "\n"
	msg += "Photos Shared: " + format(dataDict['PhotosSharedOldUsers'], ",d") + "\n"

	# photos, new users
	msg += "\n--- PHOTOS (NEW USERS) ---\n"
	msg += "Photos Uploaded: " + format(dataDict['PhotosUploadedNewUsers'], ",d") + "\n"
	msg += "Photos Shared: " + format(dataDict['PhotosSharedNewUsers'], ",d") + "\n"

	# actions, old users
	msg += "\n--- ACTIONS (OLD USERS) ---\n"	
	msg += "Swaps Created: " + str(dataDict['SwapsCreatedOldUsers']) + '\n'
	msg += "Swaps Joined: " + str(dataDict['SwapsJoinedOldUsers']) + '\n'	
	msg += "Photos Added: " + str(dataDict['PhotosAddedOldUsers']) + '\n'	
	msg += "Favorites: " + str(dataDict['FavsOldUsers']) + '\n'
	msg += "Comments: " + str(dataDict['CommentsOldUsers']) + '\n'

	# actions, new users
	msg += "\n--- ACTIONS (NEW USERS) ---\n"	
	msg += "Swaps Created: " + str(dataDict['SwapsCreatedNewUsers']) + '\n'
	msg += "Swaps Joined: " + str(dataDict['SwapsJoinedNewUsers']) + '\n'	
	msg += "Photos Added: " + str(dataDict['PhotosAddedNewUsers']) + '\n'	
	msg += "Favorites: " + str(dataDict['FavsNewUsers']) + '\n'
	msg += "Comments: " + str(dataDict['CommentsNewUsers']) + '\n'	
	return msg


def writeToSpreadsheet(dataDict, length):
	gdClient = gdata.spreadsheet.service.SpreadsheetsService()
	# Authenticate using your Google Docs email address and password.
	gdClient.ClientLogin('stats.master@duffytech.co', 'bich3toc8ar7ogg3uv6o')
	gdClient.ProgrammaticLogin()
	key = '1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys'

	feed = gdClient.GetWorksheetsFeed(key)
	if length == 7:
		idParts = feed.entry[0].id.text.split('/')
		worksheetId = idParts[len(idParts) - 1]
	elif length == 1:
		idParts = feed.entry[1].id.text.split('/')
		worksheetId = idParts[len(idParts) - 1]
	else:
		print "...FAILED: Invalid length field. Not writing to spreadsheet!"
		return False

	# convert all keys to lowercase (Gdata requirement) and all values to string
	cleanedUpDict = dict((k.lower(), str(v)) for k,v in dataDict.iteritems())

	result = gdClient.InsertRow(cleanedUpDict, key, worksheetId)

	if isinstance(result, gdata.spreadsheet.SpreadsheetsList):
		return True
	else:
		print "...FAILED worksheet for %s-day stats" % (length)
		return False	


def main(argv):
	logger.info("Starting... ")

	# parse inputs
	sendEmail = publishToSpreadSheet = False
	tzinfo = pytz.timezone('US/Eastern')
	date = datetime.today().replace(tzinfo=tzinfo, hour=0, minute=0, second=0)	
	date = date - relativedelta(days=0) #modify the 0 in this row to get past data

	if (len(argv) > 0):
		if ("sendall" in argv):
			sendEmail = publishToSpreadSheet = True
		elif ("sendemail" in argv):
			sendEmail = True
		elif ("publish" in argv):
			publishToSpreadSheet = True

	print "Generating stats for %s " % (date-relativedelta(days=1)).strftime('%m/%d/%Y')

	# Compile data
	dataDict1day = compileData(date, 1)
	dataDict7day = compileData(date, 7)

	# compile string to publish to console and/or email
	emailBody = dataDictToString(dataDict7day, 7)
	emailBody += dataDictToString(dataDict1day, 1)

	print emailBody

	# Send to spreadsheet
	if publishToSpreadSheet:
		print "Publishing to spreadsheet..."
		writeSeven = writeToSpreadsheet(dataDict7day, 7) # second param is length of stats like 7-day
		writeOne = writeToSpreadsheet(dataDict1day, 1) # second param is useful for figuring out which worksheet
		if writeSeven:
			print '...Published %s-day stats' % (7)
		if writeOne:
			print '...Published %s-day stats' % (1)

	# Send to email
	if sendEmail:
		emailTo = ['swap-stats@duffytech.co']
		emailSubj = 'Daily Stats'
		email = EmailMessage(emailSubj, emailBody, 'prod@duffyapp.com',emailTo, 
			[], headers = {'Reply-To': 'swap-stats@duffytech.co'})	
		email.send(fail_silently=False)
		print 'Email Sent to: ' + ' '.join(emailTo)	

	if not publishToSpreadSheet and not sendEmail:
		print 'TEST RUN: Email not sent and nothing published.'
		print "Use 'python scripts/sendDailyStats.py [sendall|sendemail|publish] '!\n"

		
		
if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
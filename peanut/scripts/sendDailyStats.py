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
	dataDictDate = {'date': (date-relativedelta(days=1)).strftime('%m/%d/%y')}
	dataDictLocalytics = getStatsFromLocalytics(date, length)
	dataDictUsers = getUserStats(date, length, newUsers)
	dataDictPhotos = getPhotoStats(date, length, newUsers)
	dataDictActions = getActionStats(date, length, newUsers)

	return dict(dataDictDate.items() + dataDictLocalytics.items() + dataDictUsers.items() + dataDictPhotos.items() + dataDictActions.items())

def getNewUsers(date, length):
	newUsers = User.objects.filter(product_id=2).filter(added__lt=date).filter(added__gt=date-relativedelta(days=length))
	return list(newUsers)

def getUserStats(date, length, newUsers):

	activeUsers = Action.objects.values('user').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).distinct().count()
	newUsers = len(newUsers)
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
	dataDict['PhotoEvalsOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_PHOTO_EVALUATED)

	# new users
	actionTypeCounts = Action.objects.values('action_type').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).filter(user__in=newUsers).annotate(totals=Count('action_type'))

	dataDict['SwapsCreatedNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_CREATE_STRAND)
	dataDict['SwapsJoinedNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_JOIN_STRAND)
	dataDict['PhotosAddedNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND)
	dataDict['FavsNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_FAVORITE)
	dataDict['CommentsNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_COMMENT)
	dataDict['PhotoEvalsNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_PHOTO_EVALUATED)	


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
	msg += "Localytics Users: " + str(dataDict['LocalyticsActiveUsers']) + "\n"
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
	msg += "Photos Eval'd: " + str(dataDict['PhotoEvalsOldUsers']) + '\n'		
	msg += "Favorites: " + str(dataDict['FavsOldUsers']) + '\n'
	msg += "Comments: " + str(dataDict['CommentsOldUsers']) + '\n'

	# actions, new users
	msg += "\n--- ACTIONS (NEW USERS) ---\n"	
	msg += "Swaps Created: " + str(dataDict['SwapsCreatedNewUsers']) + '\n'
	msg += "Swaps Joined: " + str(dataDict['SwapsJoinedNewUsers']) + '\n'	
	msg += "Photos Added: " + str(dataDict['PhotosAddedNewUsers']) + '\n'	
	msg += "Photos Eval'd: " + str(dataDict['PhotoEvalsNewUsers']) + '\n'			
	msg += "Favorites: " + str(dataDict['FavsNewUsers']) + '\n'
	msg += "Comments: " + str(dataDict['CommentsNewUsers']) + '\n'	
	return msg

def getStatsFromLocalytics(date, length):

	# Localytics API info

	url = 'https://api.localytics.com/v1/query?'
	apiKey = '3dbadf00bdd71c6a99286ba-b9ff00a6-89c4-11e4-29be-004a77f8b47f'
	apiSecret = 'd19228fc63c4336a11d9d30-b9ff05d6-89c4-11e4-29be-004a77f8b47f'
	appID = 'b9370b33afb6b68728b25b7-952efd94-8487-11e4-5060-00a426b17dd8' #swap v2
	#appID = 'dd0a7a0a4c9c1a5a602904f-285e4dea-5c55-11e4-a3a4-005cf8cbabd8' #swap v1
	headers = {'Content-Type': "application/json"}

	payload = {'api_key': apiKey,
				'api_secret': apiSecret,
				'app_id': appID,
				'metrics': 'users'}

	#Format payloads and dates
	# NOTE: Localytics doesn't have rolling 7-day actives. They are only avaiable for Mondays.
	# 7-day actives for week of 12-15-2014 to 12-22-2014 will be under 12/15/2014

	dateEndFormatted = date.strftime('%Y-%m-%d')

	if length == 1:
		dimension = 'day'
		dateBeginFormatted = (date-relativedelta(days=1)).strftime('%Y-%m-%d')
		conditions = {'day': ['between', dateBeginFormatted, dateEndFormatted]}
		payload['dimensions'] = dimension
	elif length == 7:
		dimension = 'week'
		dateBeginFormatted = (date-relativedelta(days=7)).strftime('%Y-%m-%d')
		conditions = {'week': ['between', dateBeginFormatted, dateEndFormatted]}
		payload['dimensions'] = dimension
	else:
		print "ERROR: length needs to be either 1 or 7"
		sys.exit()

	# Send the request to Localytics
	response = requests.post(url, data=json.dumps(payload), headers=headers)

	# parse results
	parsedResponse = json.loads(response.text)

	if 'results' in parsedResponse:
		for entry in parsedResponse['results']:
			if dimension in entry and entry[dimension] == dateBeginFormatted:
				return {'LocalyticsActiveUsers': entry['users']} 
				break

	return {'LocalyticsActiveUsers': ''}

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

	# get the existing feed, so we can upate right entry
	# Note: we need to updateRow, instead of InsertRow. GData graphing quirks
	listFeed = gdClient.GetListFeed(key, worksheetId)
	rowIndex = None
	for i, listEntry in enumerate(listFeed.entry):
		if (listEntry.title.text == dataDict['date']):
			rowIndex = i

	if rowIndex != None:
		result = gdClient.UpdateRow(listFeed.entry[rowIndex], cleanedUpDict)
		if isinstance(result, gdata.spreadsheet.SpreadsheetsList):
			return True
		else:
			print "...FAILED worksheet for %s-day stats" % (length)
			return False
	else:
		print 'Error: date not found in spreadsheet. Please update first!'

	return False

def genHTML(emailBody):
	time = (datetime.now() - datetime(1970,1,1)).total_seconds()
	html = "<html><body>"
	html += '<h2> 7-day users </h2>'
	html += '<img src="https://docs.google.com/spreadsheets/d/1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys/pubchart?oid=865122525&format=image&rand=' + str(time) + '">'
	html += '<h2> 1-day users </h2>'	
	html += '<img src="https://docs.google.com/spreadsheets/d/1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys/pubchart?oid=60601290&format=image&rand=' + str(time) + '">'
	html += '<h2> Actions </h2>'
	html += '<img src="https://docs.google.com/spreadsheets/d/1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys/pubchart?oid=1473168963&format=image&rand='+ str(time) + '">'
	html += '<h3><a href ="https://docs.google.com/a/duffytech.co/spreadsheets/d/1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys/edit#gid=1659973534">Raw data and stats</a></h3>'
	html += '<pre>' + emailBody + '</pre>'	
	html +="</body></html>"
	return html


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

	print "Generating stats for %s " % (date-relativedelta(days=1)).strftime('%m/%d/%y')

	# Compile data
	dataDict1day = compileData(date, 1)
	dataDict7day = compileData(date, 7)

	# compile string to publish to console and/or email
	emailBody = dataDictToString(dataDict7day, 7)
	emailBody += dataDictToString(dataDict1day, 1)

	print emailBody

	html = genHTML(emailBody)


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
		email = EmailMultiAlternatives(emailSubj, emailBody, 'prod@duffyapp.com',emailTo, 
			[], headers = {'Reply-To': 'swap-stats@duffytech.co'})	
		email.attach_alternative(html, "text/html")
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
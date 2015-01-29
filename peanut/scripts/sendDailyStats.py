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
from common.models import User, FriendConnection, Action, Photo, StrandNeighbor, ShareInstance, NotificationLog

logger = logging.getLogger(__name__)

###############################
### Data fetching functions ###
###############################


def compileData(date, length):

	'''
		Subject: Daily Stats
		
		--- USERS ---
		Active users:
		New Users:
		New Friends: 
		Check-ins:
		Location Updates:
		
		--- PHOTOS (OLD USERS) ---
		Photos Uploaded:		
		Photos Shared: 

		--- PHOTOS (NEW USERS) ---
		Photos Uploaded:		
		Photos Shared: 

		--- ACTIONS (OLD USERS) ---
		Photos Added:
		Favorites:
		Comments:

		--- ACTIONS (NEW USERS) ---
		Photos Added:
		Favorites:
		Comments:

		--- Totals ---
		User Accounts:
		Friend Connections:
		Share Instances:
		Photos (metadata):

	'''

	newUsers = getNewUsers(date, length)
	dataDictDate = {'date': (date-relativedelta(days=1)).strftime('%m/%d/%y')}
	dataDictLocalytics = getStatsFromLocalytics(date, length)
	dataDictUsers = getUserStats(date, length, newUsers)
	dataDictPhotos = getPhotoStats(date, length, newUsers)
	dataDictActions = getActionStats(date, length, newUsers)

	return dict(dataDictDate.items() + dataDictLocalytics.items() + dataDictUsers.items() + dataDictPhotos.items() + dataDictActions.items())

def getNewUsers(date, length):
	newUsers = User.objects.filter(product_id=2).filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).filter(has_sms_authed=True)
	return list(newUsers)

def getUserStats(date, length, newUsers):

	activeUsers = Action.objects.filter(Q(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED) | Q(action_type=constants.ACTION_TYPE_FAVORITE) | Q(action_type=constants.ACTION_TYPE_COMMENT)).values('user').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).distinct().count()
	newUsers = len(newUsers)
	newFriends = FriendConnection.objects.filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).count()
	checkIns = User.objects.filter(last_checkin_timestamp__lt=date).filter(last_checkin_timestamp__gt=date-relativedelta(days=length)).count()
	locationUpdates = User.objects.filter(last_location_timestamp__lt=date).filter(last_location_timestamp__gt=date-relativedelta(days=length)).count()	

	# note that gdata api requires that dictionary keys be all lowercase and no spaces
	return {'ActiveUsers': activeUsers,
			'NewUsers': newUsers, 
			'NewFriends': newFriends, 
			'CheckIns': checkIns,
			'LocationUpdates': locationUpdates}


def getPhotoStats(date, length, newUsers):

	# Old users
	newPhotosUploadedOldUsers = Photo.objects.filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).exclude(user__in=newUsers).count()
	newPhotosSharedOldUsers = ShareInstance.objects.exclude(user__in=newUsers).filter(shared_at_timestamp__gt=(date-relativedelta(days=length))).filter(shared_at_timestamp__lt=date).values('user').annotate(totalPhotos=Count('user')).aggregate(Sum('totalPhotos'))['totalPhotos__sum']
	if newPhotosSharedOldUsers == None:
		newPhotosSharedOldUsers = 0

	# new users
	newPhotosUploadedNewUsers = Photo.objects.filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).filter(user__in=newUsers).count()
	newPhotosSharedNewUsers = ShareInstance.objects.filter(user__in=newUsers).filter(shared_at_timestamp__lt=(date-relativedelta(days=length))).filter(shared_at_timestamp__lt=date).values('user').annotate(totalPhotos=Count('user')).aggregate(Sum('totalPhotos'))['totalPhotos__sum']
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
	actionTypeCounts = Action.objects.filter(Q(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED) | Q(action_type=constants.ACTION_TYPE_FAVORITE) | Q(action_type=constants.ACTION_TYPE_COMMENT)).values('action_type').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).exclude(user__in=newUsers).annotate(totals=Count('action_type'))

	dataDict['FavsOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_FAVORITE)
	dataDict['CommentsOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_COMMENT)
	dataDict['PhotoEvalsOldUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_PHOTO_EVALUATED)

	# new users
	actionTypeCounts = Action.objects.filter(Q(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED) | Q(action_type=constants.ACTION_TYPE_FAVORITE) | Q(action_type=constants.ACTION_TYPE_COMMENT)).values('action_type').filter(added__lt=date).filter(added__gt=date-relativedelta(days=length)).filter(user__in=newUsers).annotate(totals=Count('action_type'))

	dataDict['FavsNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_FAVORITE)
	dataDict['CommentsNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_COMMENT)
	dataDict['PhotoEvalsNewUsers'] = actionStatsHelper(actionTypeCounts, constants.ACTION_TYPE_PHOTO_EVALUATED)	


	return dataDict

def actionStatsHelper(actionTypeCounts, actionType):
	for entry in actionTypeCounts:
		if (entry['action_type'] == actionType):
			return entry['totals']
	return 0

def getTotals(date):
	dataDict = {}

	dataDict['date'] = (date-relativedelta(days=1)).strftime('%m/%d/%y')
	dataDict['TotalUserAccounts'] = User.objects.filter(product_id=2).filter(added__lt=date).count()
	dataDict['TotalFriends'] = FriendConnection.objects.filter(added__lt=date).filter(Q(user_1_id__gt=5000) & Q(user_2_id__gt=5000)).count()
	dataDict['TotalShareInstances'] = ShareInstance.objects.filter(added__lt=date).count()
	dataDict['TotalPhotosMetadata'] = Photo.objects.exclude(id__lt=7463).exclude(Q(install_num=-1) & Q(thumb_filename = None)).filter(added__lt=date).count() #ignores deleted photos

	return dataDict

def calcNotificationData(date):

	NOTIFICATIONS_USED_DICT = {
		constants.NOTIFICATIONS_NEW_PHOTO_ID : True,
		constants.NOTIFICATIONS_JOIN_STRAND_ID : False,
		constants.NOTIFICATIONS_PHOTO_FAVORITED_ID : True,
		constants.NOTIFICATIONS_FETCH_GPS_ID : True,
		constants.NOTIFICATIONS_UNSEEN_PHOTOS_FS : False,
		constants.NOTIFICATIONS_ACTIVATE_ACCOUNT_FS : True,
		constants.NOTIFICATIONS_REFRESH_FEED : True,
		constants.NOTIFICATIONS_SOCKET_REFRESH_FEED: True,	
		constants.NOTIFICATIONS_INVITED_TO_STRAND : False,
		constants.NOTIFICATIONS_ACCEPTED_INVITE : False,
		constants.NOTIFICATIONS_RETRO_FIRESTARTER : False,
		constants.NOTIFICATIONS_UNACCEPTED_INVITE_FS : False,
		constants.NOTIFICATIONS_PHOTO_COMMENT : True,
		constants.NOTIFICATIONS_NEW_SUGGESTION : True,
	}

	dataDict = dict()

	dataDict['date'] = (date-relativedelta(days=1)).strftime('%m/%d/%y')

	for key, item in NOTIFICATIONS_USED_DICT.items():
		if item:
			sent, userCount = notificationCountsHelper(key, date)
			dataDict['NotificationID'+ str(key) +'Sent'] = sent
			dataDict['NotificationID'+ str(key) +'Users'] = userCount	
	return dataDict

def notificationCountsHelper(msgTypeId, date):

	notificationLogs = NotificationLog.objects.filter(added__lt=date).filter(added__gt=date-timedelta(days=1)).filter(msg_type=msgTypeId).filter(Q(result=constants.IOS_NOTIFICATIONS_RESULT_SENT) | Q(result=constants.IOS_NOTIFICATIONS_RESULT_SMS_SENT_INSTEAD))

	sent = len(notificationLogs)
	userSet = set()
	for nLog in notificationLogs:
		userSet.add(nLog.user)

	userList = list(userSet)
	userCount = len(userList)

	return sent, userCount

def getStatsFromLocalytics(date, length):

	logger.info("Fetching data from Localytics for %s-day"%(length))

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
		logger.error("ERROR: length needs to be either 1 or 7")
		sys.exit()

	# Send the request to Localytics
	response = requests.post(url, data=json.dumps(payload), headers=headers)

	# parse results
	parsedResponse = json.loads(response.text)

	logger.info("Looking for date %s in Localytics results (%s-day)"%(dateBeginFormatted, length))

	if 'results' in parsedResponse:
		for entry in parsedResponse['results']:
			if dimension in entry and (entry[dimension] == dateBeginFormatted or entry[dimension] == (dateBeginFormatted+'T00:00:00Z')):
				logger.info("found!")
				return {'LocalyticsActiveUsers': entry['users']} 
				break
	logger.info("Not found!")
	return {'LocalyticsActiveUsers': ''}

###############################
### Rendering functions     ###
###############################

def dataDictToString(dataDict, title, html=False):
	if html:
		string = '<p>' + title.upper() + '<\p>'
	else:
		string = '\n' + title.upper() + '\n'

	for key,item in dataDict.items():
		if key != 'date':
			val = "%s: %s"%(key,item)
			if html:
				string += '<p>' + val + '<\p>'
			else:
				string += val + '\n'
	return string


def dataDictTotalsToString(dataDict):
	msg = "\n--- TOTALS ---\n"
	msg += "User Accounts: " + str(dataDict['TotalUserAccounts']) + "\n"
	msg += "Friends: " + str(dataDict['TotalFriends']) + "\n"
	msg += "Share Instances: " + str(dataDict['TotalShareInstances']) + "\n"
	msg += "Photos (metadata): " + str(dataDict['TotalPhotosMetadata']) + "\n"	

	return msg

def dataDictToStringOld(dataDict, length):

	msg = "\n" + str(length) + "-day stats for " + dataDict['date'] + "\n"

	# users	
	msg += "\n--- USERS ---\n"
	msg += "Localytics Users: " + str(dataDict['LocalyticsActiveUsers']) + "\n"
	msg += "Active Users: " + str(dataDict['ActiveUsers']) + "\n"
	msg += "New Users: " + str(dataDict['NewUsers']) + "\n"
	msg += "New Friends: " + str(dataDict['NewFriends']) + "\n"
	msg += "Check-ins: " + str(dataDict['CheckIns']) + "\n"
	msg += "Location Updates: " + str(dataDict['LocationUpdates']) + "\n"	

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
	msg += "Photos Eval'd: " + str(dataDict['PhotoEvalsOldUsers']) + '\n'		
	msg += "Favorites: " + str(dataDict['FavsOldUsers']) + '\n'
	msg += "Comments: " + str(dataDict['CommentsOldUsers']) + '\n'

	# actions, new users
	msg += "\n--- ACTIONS (NEW USERS) ---\n"	
	msg += "Photos Eval'd: " + str(dataDict['PhotoEvalsNewUsers']) + '\n'			
	msg += "Favorites: " + str(dataDict['FavsNewUsers']) + '\n'
	msg += "Comments: " + str(dataDict['CommentsNewUsers']) + '\n'

	return msg

def genHTML(emailBody):
	time = (datetime.now() - datetime(1970,1,1)).total_seconds()
	html = "<html><body>"
	html += '<h2> 7-day users </h2>'
	html += '<img height="288" width="465" src="https://docs.google.com/spreadsheets/d/1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys/pubchart?oid=865122525&format=image&rand=' + str(time) + '">'
	html += '<h4>* Localytics only has 7-day actives for Mondays. No rolling 7-day actives.</h4>'
	html += '<h2> 1-day users </h2>'
	html += '<img height="288" width="465" src="https://docs.google.com/spreadsheets/d/1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys/pubchart?oid=60601290&format=image&rand=' + str(time) + '">'
	html += '<h2> Actions </h2>'
	html += '<img height="288" width="465" src="https://docs.google.com/spreadsheets/d/1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys/pubchart?oid=1473168963&format=image&rand='+ str(time) + '">'
	html += '<h3><a href ="https://docs.google.com/a/duffytech.co/spreadsheets/d/1qAXGN3-1mxutctXGQQsDP-CNR9IGGhjAGt61RTpAkys/edit#gid=1659973534">Raw data and stats</a></h3>'
	html += '<pre>' + emailBody + '</pre>'	
	html +="</body></html>"
	return html

###############################
### Publishing functions    ###
###############################

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
	elif length == 0: #used for totals worksheet, where length doesn't matter
		idParts = feed.entry[2].id.text.split('/')
		worksheetId = idParts[len(idParts) - 1]
	elif length == -1:
		idParts = feed.entry[3].id.text.split('/')
		worksheetId = idParts[len(idParts) - 1]		
	else:
		logger.info("...FAILED: Invalid length field. Not writing to spreadsheet!")
		return False

	# convert all keys to lowercase (Gdata requirement) and all values to string
	cleanedUpDict = dict((k.lower().replace(" ", ""), str(v)) for k,v in dataDict.iteritems())		

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
			logger.error("...FAILED worksheet for %s-day stats" % (length))
			return False
	else:
		logger.error('Error: date not found in spreadsheet. Please update first!')

	return False

def sendEmailOut(txtBody, htmlBody):
	emailTo = ['swap-stats@duffytech.co']
	emailSubj = 'Daily Stats'
	email = EmailMultiAlternatives(emailSubj, txtBody, 'prod@duffyapp.com',emailTo, 
		[], headers = {'Reply-To': 'swap-stats@duffytech.co'})	
	email.attach_alternative(htmlBody, "text/html")
	email.send(fail_silently=False)
	logger.info('Email Sent to: ' + ' '.join(emailTo))


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

	logger.info("Generating stats for %s " % (date-relativedelta(days=1)).strftime('%m/%d/%y'))

	# Compile data for users and activity
	dataDict1day = compileData(date, 1)
	dataDict7day = compileData(date, 7)
	dataDictTotals = getTotals(date)

	# Compile data for notifications and resulting activity
	dataDictNotifications = calcNotificationData(date)
	logger.info(dataDictNotifications)

	# compile string to publish to console and/or email
	emailBody = dataDictToStringOld(dataDict7day, 7)
	emailBody += dataDictToStringOld(dataDict1day, 1)
	emailBody += dataDictTotalsToString(dataDictTotals)
	emailBody += dataDictToString(dataDictNotifications, '--- Notifications ---', False)

	logger.info(emailBody)

	html = genHTML(emailBody)


	# Send to spreadsheet
	if publishToSpreadSheet:
		logger.info("Publishing to spreadsheet...")
		writeSeven = writeToSpreadsheet(dataDict7day, 7) # second param is length of stats like 7-day
		if writeSeven:
			logger.info('...Published %s-day stats' % (7))		
		writeOne = writeToSpreadsheet(dataDict1day, 1) # second param is useful for figuring out which worksheet
		if writeOne:
			logger.info('...Published %s-day stats' % (1))
		writeTotals = writeToSpreadsheet(dataDictTotals, 0)
		if writeTotals:
			logger.info('...Published Totals stats')
		writeNotifications = writeToSpreadsheet(dataDictNotifications, -1)
		if writeNotifications:
			logger.info('...Published Notification stats')

	# Send to email
	if sendEmail:
		sendEmailOut(emailBody, html)

	if not publishToSpreadSheet and not sendEmail:
		print 'TEST RUN: Email not sent and nothing published.'
		print "Use 'python scripts/sendDailyStats.py [sendall|sendemail|publish] '!\n"

	logger.info('Finished')
		
		
if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/daily-stats.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
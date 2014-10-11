import os, datetime
import json
from collections import OrderedDict
from datetime import datetime, date, timedelta
from dateutil.relativedelta import relativedelta
from dateutil import tz
import time, math, urllib
import pytz
import logging

from django.shortcuts import render
from django.http import HttpResponse

from django.template import RequestContext, loader
from django.db.models import Q, Count, Max
from django.db import connection

from peanut.settings import constants

from common.models import Photo, User, Classification, NotificationLog, Strand, Action

from arbus import image_util, search_util
from arbus.forms import ManualAddPhoto

logger = logging.getLogger(__name__)
	
def userbaseSummary(request):
	knownPhoneIds = {	'AA94D207-D1E8-4098-9A39-76A3A1CC81FB',
						'BA8E652E-6BD4-4DC7-B8A0-7157FFA51DEC',
						'0012F94E-E6AF-429A-8530-E1011E1BFCAE',
						'CEE91F90-263A-4BF1-AED7-6AB27B7BC076',
						'F7092B08-EF4D-40EF-896D-0539CB102D3D',
						'3E8018C0-1BE5-483D-89C4-85CD66F81298',
						'26A1609E-BBBA-4684-8DF0-A394500FA96B',
						'1067880F-AB7B-4B06-95AB-DE5216DD3CA0',
						'55BE5A34-0188-4B0B-805E-45B30808CA61',
						'BEEF'}

	arbusList = list()
	to_zone = tz.gettz('America/New_York')

	# StrandV2-related code
	strandV2List = list()


	userStats = User.objects.filter(product_id=2).annotate(totalCount=Count('photo'), thumbsCount=Count('photo__thumb_filename'), 
			photosWithGPS=Count('photo__location_point'), twofishCount=Count('photo__twofishes_data'), 
			fullImagesCount=Count('photo__full_filename'), clusteredCount=Count('photo__clustered_time'), 
			strandedCount=Count('photo__strand_evaluated'), lastUpdated=Max('photo__updated'), lastAdded=Max('photo__added'))

	# This photo call is taking over a second on the dev database right now.
	photoDataRaw = Photo.objects.filter(thumb_filename__isnull=False).exclude(added__lt=(datetime.now()-timedelta(hours=168))).values('user').annotate(weeklyPhotos=Count('user'))
	strandDataRaw = Strand.objects.filter(private=False).exclude(added__lt=(datetime.now()-timedelta(hours=168))).values('users').annotate(weeklyStrands=Count('users'))	
	actionDataRaw = Action.objects.exclude(added__lt=(datetime.now()-timedelta(hours=168))).values('user', 'action_type', 'added').annotate(weeklyActions=Count('user'))
	#friendsDataRaw = FriendConnection.objects.exclude(added__lt=(datetime.now()-timedelta(hours=168))).values('user').order_by().annotate(totalFriends=Count('user'))
	#contactsDataRaw = ContactEntry.objects.exclude(added__lt=(datetime.now()-timedelta(hours=168))).values('user').order_by().annotate(totalContacts=Count('user'))	

	#actionsCount = list(User.objects.filter(product_id=2).annotate(totalActions=Count('action')).order_by('-id'))
	#strandCount = list(User.objects.filter(product_id=1).annotate(totalStrands=Count('strand__shared')).order_by('-id'))
	inviteCount = list(User.objects.filter(product_id=2).annotate(totalInvites=Count('inviting_user')).order_by('-id'))
	contactCount = list(User.objects.filter(product_id=2).annotate(totalContacts=Count('contactentry')).order_by('-id'))
	friendCount = list(User.objects.filter(product_id=2).annotate(totalFriends1=Count('friend_user_1', distinct=True), totalFriends2=Count('friend_user_2', distinct=True)).order_by('-id'))

	extras = dict()
	for i in range(len(userStats)):
		entry = dict()
		#entry['actions'] = actionsCount[i].totalActions
		#entry['strands'] = strandCount[i].totalStrands
		entry['contacts'] = contactCount[i].totalContacts
		entry['friends'] = friendCount[i].totalFriends1 + friendCount[i].totalFriends2
		entry['invites'] = inviteCount[i].totalInvites
		extras[contactCount[i].id] = entry

	# Exclude type GPS fetch since it happens so frequently
	notificationDataRaw = NotificationLog.objects.filter(result=constants.IOS_NOTIFICATIONS_RESULT_SENT).exclude(msg_type=constants.NOTIFICATIONS_FETCH_GPS_ID).exclude(msg_type=constants.NOTIFICATIONS_REFRESH_FEED).exclude(added__lt=(datetime.now()-timedelta(hours=168))).values('user').order_by().annotate(totalNotifs=Count('user'), lastSent=Max('added'))
	notificationCountById = dict()
	notificationLastById = dict()

	for notificationData in notificationDataRaw:
		notificationCountById[notificationData['user']] = notificationData['totalNotifs']
		notificationLastById[notificationData['user']] = notificationData['lastSent']	

	weeklyPhotosById = dict()
	for photoData in photoDataRaw:
		weeklyPhotosById[photoData['user']] = photoData['weeklyPhotos']

	weeklyStrandsById = dict()
	for strandData in strandDataRaw:
		weeklyStrandsById[strandData['users']] = strandData['weeklyStrands']

	''' # from constants.py
	ACTION_TYPE_FAVORITE = 0
	ACTION_TYPE_CREATE_STRAND = 1
	ACTION_TYPE_ADD_PHOTOS_TO_STRAND = 2
	ACTION_TYPE_JOIN_STRAND = 3
	'''

	weeklyFavsById = dict() #action_type=0
	weeklyStrandsCreatedById = dict() #action_type=1
	weeklyPhotosAddedById = dict() #action_type=2
	weeklyStrandsJoinedById = dict() #action_type =3
	lastActionTimeById = dict()

	for actionData in actionDataRaw:
		#weeklyActionsById[actionData['user']] = actionData['weeklyActions']
		if (actionData['action_type'] == 0):
			weeklyFavsById[actionData['user']] = actionData['weeklyActions']
		elif (actionData['action_type'] == 1):
			weeklyStrandsCreatedById[actionData['user']] = actionData['weeklyActions']
		elif (actionData['action_type'] == 2):
			weeklyPhotosAddedById[actionData['user']] = actionData['weeklyActions']		
		elif (actionData['action_type'] == 3):
			weeklyStrandsJoinedById[actionData['user']] = actionData['weeklyActions']

		if actionData['user'] in lastActionTimeById:
			if lastActionTimeById[actionData['user']] < actionData['added']:
				lastActionTimeById[actionData['user']] = actionData['added']
		else:
			lastActionTimeById[actionData['user']] = actionData['added']

	for i, user in enumerate(userStats):
		entry = dict()
		entry['user'] = user
		if (user.added):
			entry['userCreated'] = user.added.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
		if (user.last_location_timestamp):
			entry['lastLocationTimestamp'] = user.last_location_timestamp.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')


		if (user.totalCount > 0):
			entry['lastUploadTime'] = user.lastUpdated.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
			entry['metadataCount'] = user.totalCount - user.thumbsCount

		if user.id in notificationCountById:
			entry['notifications'] = notificationCountById[user.id]
			entry['lastNotifSent'] = notificationLastById[user.id].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
		else:
			entry['notifications'] = '-'

		if user.id in weeklyPhotosById:
			entry['weeklyPhotos'] = weeklyPhotosById[user.id]
		else:
			entry['weeklyPhotos'] = '-'

		if user.id in weeklyStrandsById:
			entry['weeklyStrands'] = weeklyStrandsById[user.id]
		else:
			entry['weeklyStrands'] = '-'

		if user.id in weeklyFavsById:
			entry['weeklyFavs'] = weeklyFavsById[user.id]
		else:
			entry['weeklyFavs'] = '-'

		if user.id in weeklyStrandsCreatedById:
			entry['weeklyStrandsCreated'] = weeklyStrandsCreatedById[user.id]
		else:
			entry['weeklyStrandsCreated'] = '-'

		if user.id in weeklyPhotosAddedById:
			entry['weeklyPhotosAdded'] = weeklyPhotosAddedById[user.id]
		else:
			entry['weeklyPhotosAdded'] = '-'

		if user.id in weeklyStrandsJoinedById:
			entry['weeklyStrandsJoined'] = weeklyStrandsJoinedById[user.id]
		else:
			entry['weeklyStrandsJoined'] = '-'

		if user.id in lastActionTimeById:
			entry['lastActionTime'] = lastActionTimeById[user.id]
		else:
			print "No actions found for user %s" % (user.id)
			entry['lastActionTime'] = user.added


		entry['contactCount'] = extras[user.id]['contacts']
		entry['friendCount'] = extras[user.id]['friends']
		entry['inviteCount'] = extras[user.id]['invites']


		if user.last_build_info:
			buildNum = user.last_build_info[user.last_build_info.find('-'):]
			if ('enterprise' in user.last_build_info.lower()):
				entry['build'] = 'e' + buildNum
			elif ('dp' in user.last_build_info.lower()):
				entry['build'] = 'd' + buildNum
			else:
				entry['build'] = 's' + buildNum


		entry['internal'] = False

		if ((len(user.display_name) == 0) or 
			('555555' in str(user.phone_number))):
			entry['internal'] = True
		else:
			for phoneid in knownPhoneIds:
				if ((phoneid.lower() in user.phone_id.lower()) or 
					('iphone simulator'.lower() in user.display_name.lower()) or
					('ipad simulator'.lower() in user.display_name.lower())):
					entry['internal'] = True
					break
			
			for phoneNum in constants.DEV_PHONE_NUMBERS:
				if (user.phone_number and phoneNum in str(user.phone_number)):
					entry['internal'] = True
					break

		strandV2List.append(entry)

	strandV2List = sorted(strandV2List, key=lambda x: x['lastActionTime'], reverse=True)


	context = {	'arbusList': list(),
				'strandList': list(),
				'strandV2List': strandV2List}
	return render(request, 'admin/userbaseSummary.html', context)

# Helper functions

def setSession(request, userId):
	request.session['userid'] = userId




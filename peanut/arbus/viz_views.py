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
from django.db.models import Q, Count, Max, Sum, F
from django.db import connection

from peanut.settings import constants

from common.models import Photo, User, Classification, NotificationLog, Action, ShareInstance, LocationRecord

from arbus import image_util, search_util
from arbus.forms import ManualAddPhoto
from common import stats_util

logger = logging.getLogger(__name__)
	
def userbaseSummary(request):

	# get now and always round up the hour to let database build its cache
	now = datetime.utcnow().replace(tzinfo=pytz.utc)
	newNow = now.replace(microsecond=0, second=0, minute=0)+timedelta(hours=1)

	# database calls
	userStats = list(User.objects.filter(product_id=2))
	actionDataRaw = list(Action.objects.exclude(added__lt=(newNow-timedelta(hours=168))).filter(Q(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED) | Q(action_type=constants.ACTION_TYPE_FAVORITE) | Q(action_type=constants.ACTION_TYPE_COMMENT)).values('user', 'action_type').annotate(weeklyActions=Count('user'), lastActionTimestamp=Max('added')))
	siDataForWeeklyPhotos = list(ShareInstance.objects.exclude(shared_at_timestamp__lt=(newNow-timedelta(hours=168))).values('users').annotate(weeklyPhotosShared=Count('user')))
	siDataForAllPhotos = list(ShareInstance.objects.values('users').annotate(allPhotosShared=Count('user')))
	locationData = list(LocationRecord.objects.values('user').annotate(lastUpdated=Max('updated')))
	contactCount = list(User.objects.filter(product_id=2).annotate(totalContacts=Count('contactentry')).order_by('-id'))
	friendCount = list(User.objects.filter(product_id=2).annotate(totalFriends1=Count('friend_user_1', distinct=True), totalFriends2=Count('friend_user_2', distinct=True)).order_by('-id'))

	# Exclude type GPS fetch and socket refresh feeds since it happens so frequently
	notificationDataRaw = list(NotificationLog.objects.exclude(
		result=constants.IOS_NOTIFICATIONS_RESULT_ERROR).exclude(
		msg_type=constants.NOTIFICATIONS_FETCH_GPS_ID).exclude(
		msg_type=constants.NOTIFICATIONS_UPDATE_BADGE).exclude(
		msg_type=constants.NOTIFICATIONS_SOCKET_REFRESH_FEED).exclude(
		added__lt=newNow-timedelta(hours=168)).exclude(
		user_id__lt=600).values('user', 'msg_type').order_by('user').annotate(totalNotifs=Count('user'), lastSent=Max('added')))

	extras = dict() #store additional information per user
	for i in range(len(userStats)):
		entry = dict()
		entry['contacts'] = contactCount[i].totalContacts
		entry['ffriends'] = friendCount[i].totalFriends1
		entry['rfriends'] = friendCount[i].totalFriends2
		extras[contactCount[i].id] = entry

	notificationCountById = dict()
	notificationLastById = dict()
	notificationSuggestionsById = dict()

	for notificationData in notificationDataRaw:
		# if haven't seen this user_id, create entry in all dicts and set to 0
		if not notificationData['user'] in notificationCountById:
			notificationCountById[notificationData['user']] = 0
			notificationLastById[notificationData['user']] = notificationData['lastSent'] #setting it something older than a week
			notificationSuggestionsById[notificationData['user']] = 0

		# add current notification count to the total count for this user
		notificationCountById[notificationData['user']] += notificationData['totalNotifs']

		# if lastSent for this notification type is greater than previous tracked one, update it
		if notificationData['lastSent'] > notificationLastById[notificationData['user']]:
			notificationLastById[notificationData['user']] = notificationData['lastSent']

		# if it's a new_suggestion, track that separately
		if notificationData['msg_type'] == constants.NOTIFICATIONS_NEW_SUGGESTION:
			notificationSuggestionsById[notificationData['user']] += notificationData['totalNotifs']


	weeklyPhotosById = dict()
	PhotosDataById = dict()
	allSiById = dict()
	locationById = dict()
	
	for actionData in siDataForWeeklyPhotos:
		weeklyPhotosById[actionData['users']] = actionData['weeklyPhotosShared']

	for siData in siDataForAllPhotos:
		allSiById[siData['users']] = siData['allPhotosShared']

	for loc in locationData:
		locationById[loc['user']] = loc['lastUpdated']

	weeklyFavsById = dict() #action_type=0
	weeklyCommentsById = dict() #action_type = 4
	weeklyPhotoEvalsById = dict() #action_type = 5
	lastActionTimeById = dict()

	for actionData in actionDataRaw:
		if (actionData['action_type'] == constants.ACTION_TYPE_FAVORITE):
			weeklyFavsById[actionData['user']] = actionData['weeklyActions']
		elif (actionData['action_type'] == constants.ACTION_TYPE_COMMENT):
			weeklyCommentsById[actionData['user']] = actionData['weeklyActions']
		elif (actionData['action_type'] == constants.ACTION_TYPE_PHOTO_EVALUATED):
			weeklyPhotoEvalsById[actionData['user']] = actionData['weeklyActions']

		# append the last action time
		if actionData['user'] in lastActionTimeById:
			if lastActionTimeById[actionData['user']] < actionData['lastActionTimestamp']:
				lastActionTimeById[actionData['user']] = actionData['lastActionTimestamp']
		else:
			lastActionTimeById[actionData['user']] = actionData['lastActionTimestamp']

	peopleCounts = dict()
	peopleCounts['friends'] = 0
	swapUserList = list()
	to_zone = tz.gettz('America/New_York')
	for i, user in enumerate(userStats):
		entry = dict()
		entry['user'] = user
		if (user.added):
			entry['userCreated'] = user.added.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
		if (user.last_location_timestamp):
			entry['lastLocationTimestamp'] = user.last_location_timestamp.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')

		if (user.last_checkin_timestamp):
			entry['lastCheckinTime'] = user.last_checkin_timestamp.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')			

		if user.id in allSiById:
			user.siCount = allSiById[user.id]
		else:
			user.siCount = 0

		if user.id in locationById:
			user.lastLocationTimestamp = locationById[user.id]

		if user.id in notificationCountById:
			entry['notifications'] = notificationCountById[user.id]
			entry['lastNotifSent'] = notificationLastById[user.id].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
			entry['suggestionNotifications'] = notificationSuggestionsById[user.id]
		else:
			entry['notifications'] = '-'

		if user.id in weeklyPhotosById:
			entry['weeklyPhotos'] = weeklyPhotosById[user.id]
		else:
			entry['weeklyPhotos'] = '-'

		if user.id in weeklyFavsById:
			entry['weeklyFavs'] = weeklyFavsById[user.id]
		else:
			entry['weeklyFavs'] = '-'

		if user.id in weeklyCommentsById:
			entry['weeklyComments'] = weeklyCommentsById[user.id]
		else:
			entry['weeklyComments'] = '-'

		if user.id in weeklyPhotoEvalsById:
			entry['weeklyPhotoEvals'] = weeklyPhotoEvalsById[user.id]
		else:
			entry['weeklyPhotoEvals'] = '-'

		if user.id in lastActionTimeById:
			entry['lastActionTimestamp'] = lastActionTimeById[user.id]
		else:
			entry['lastActionTimestamp'] = user.added

		entry['lastActionTime'] = entry['lastActionTimestamp'].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')


		entry['contactCount'] = extras[user.id]['contacts']
		entry['ffriendCount'] = extras[user.id]['ffriends']
		entry['rfriendCount'] = extras[user.id]['rfriends']	


		if user.last_build_info:
			buildNum = user.last_build_info[user.last_build_info.find('-'):]
			if ('enterprise' in user.last_build_info.lower()):
				entry['build'] = 'e' + buildNum
			elif ('dp' in user.last_build_info.lower()):
				entry['build'] = 'd' + buildNum
			else:
				entry['build'] = 's' + buildNum


		entry['internal'] = False

		if ('555555' in str(user.phone_number)):
			entry['internal'] = True
		else:
			for phoneNum in constants.DEV_PHONE_NUMBERS:
				if (user.phone_number and phoneNum in str(user.phone_number)):
					entry['internal'] = True
					break

		peopleCounts['friends'] += entry['ffriendCount'] + entry['rfriendCount']

		swapUserList.append(entry)

	swapUserList = sorted(swapUserList, key=lambda x: x['lastActionTimestamp'], reverse=True)

	peopleCounts['all'] = len(swapUserList)
	peopleCounts['friends'] = peopleCounts['friends']/2

	peopleCounts['totalShareInstances'] = ShareInstance.objects.all().count()

	context = {	'swapUserList': swapUserList,
				'peopleCounts': peopleCounts}

	return render(request, 'admin/userbaseSummary.html', context)

# Helper functions

def setSession(request, userId):
	request.session['userid'] = userId




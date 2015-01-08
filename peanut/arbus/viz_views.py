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

logger = logging.getLogger(__name__)
	
def userbaseSummary(request):

	# database calls
	userStats = list(User.objects.filter(product_id=2))
	photoDataRaw = list(Photo.objects.exclude(id__lt=7463).exclude(Q(install_num=-1) & Q(thumb_filename = None)).values('user').annotate(
		totalPhotos=Count('user'), thumbsCount=Count('thumb_filename'), photosWithGPS=Count('location_point'), lastUpdated=Max('updated')))

	actionDataRaw = list(Action.objects.exclude(added__lt=(datetime.now()-timedelta(hours=168))).filter(Q(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED) | Q(action_type=constants.ACTION_TYPE_FAVORITE) | Q(action_type=constants.ACTION_TYPE_COMMENT)).values('user', 'action_type').annotate(weeklyActions=Count('user'), lastActionTimestamp=Max('added')))

	siDataForWeeklyPhotos = list(ShareInstance.objects.exclude(shared_at_timestamp__lt=(datetime.now()-timedelta(hours=168))).values('user').annotate(weeklyPhotosShared=Count('user')))
	siDataForAllPhotos = list(ShareInstance.objects.values('user').annotate(allPhotosShared=Count('user')))

	locationData = list(LocationRecord.objects.values('user').annotate(lastUpdated=Max('updated')))
	contactCount = list(User.objects.filter(product_id=2).annotate(totalContacts=Count('contactentry')).order_by('-id'))
	friendCount = list(User.objects.filter(product_id=2).annotate(totalFriends1=Count('friend_user_1', distinct=True), totalFriends2=Count('friend_user_2', distinct=True)).order_by('-id'))

	# Exclude type GPS fetch since it happens so frequently
	notificationDataRaw = list(NotificationLog.objects.filter(result=constants.IOS_NOTIFICATIONS_RESULT_SENT).exclude(msg_type=constants.NOTIFICATIONS_FETCH_GPS_ID).exclude(msg_type=constants.NOTIFICATIONS_REFRESH_FEED).exclude(added__lt=(datetime.now()-timedelta(hours=168))).values('user').order_by().annotate(totalNotifs=Count('user'), lastSent=Max('added')))

	extras = dict() #store additional information per user
	for i in range(len(userStats)):
		entry = dict()
		entry['contacts'] = contactCount[i].totalContacts
		entry['friends'] = friendCount[i].totalFriends1 + friendCount[i].totalFriends2
		extras[contactCount[i].id] = entry

	notificationCountById = dict()
	notificationLastById = dict()

	for notificationData in notificationDataRaw:
		notificationCountById[notificationData['user']] = notificationData['totalNotifs']
		notificationLastById[notificationData['user']] = notificationData['lastSent']	

	weeklyPhotosById = dict()
	PhotosDataById = dict()
	allSiById = dict()
	locationById = dict()
	
	for photosData in photoDataRaw:
		PhotosDataById[photosData['user']] = photosData

	for actionData in siDataForWeeklyPhotos:
		weeklyPhotosById[actionData['user']] = actionData['weeklyPhotosShared']

	for siData in siDataForAllPhotos:
		allSiById[siData['user']] = siData['allPhotosShared']

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


	swapUserList = list()
	to_zone = tz.gettz('America/New_York')
	peopleCounts = dict()
	peopleCounts['photosMetadata'] = 0
	peopleCounts['photosShared'] = 0
	peopleCounts['friends'] = 0

	for i, user in enumerate(userStats):
		entry = dict()
		entry['user'] = user
		if (user.added):
			entry['userCreated'] = user.added.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
		if (user.last_location_timestamp):
			entry['lastLocationTimestamp'] = user.last_location_timestamp.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')

		if (user.last_checkin_timestamp):
			entry['lastCheckinTime'] = user.last_checkin_timestamp.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')			

		if (user.id in PhotosDataById):
			user.totalCount = PhotosDataById[user.id]['totalPhotos']
			user.thumbsCount = PhotosDataById[user.id]['thumbsCount']
			user.photosWithGPS = PhotosDataById[user.id]['photosWithGPS']
			user.lastUpdated = PhotosDataById[user.id]['lastUpdated']
		else:
			user.totalCount = 0
			user.thumbsCount = 0
			user.photoWithGPS = 0
			user.lastUpdated = 0

		if user.id in allSiById:
			user.siCount = allSiById[user.id]
		else:
			user.siCount = 0

		if user.id in locationById:
			user.lastLocationTimestamp = locationById[user.id]

		if (user.totalCount > 0):
			entry['lastUploadTime'] = user.lastUpdated.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
			entry['metadataCount'] = user.totalCount
			entry['photosWithGPS'] = 100.0*float(user.photosWithGPS)/float(user.totalCount)


		if user.id in notificationCountById:
			entry['notifications'] = notificationCountById[user.id]
			entry['lastNotifSent'] = notificationLastById[user.id].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
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
			entry['lastActionTimestamp'] = '-'

		entry['lastActionTime'] = entry['lastActionTimestamp'].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')


		entry['contactCount'] = extras[user.id]['contacts']
		entry['friendCount'] = extras[user.id]['friends']


		if user.last_build_info:
			buildNum = user.last_build_info[user.last_build_info.find('-'):]
			if ('enterprise' in user.last_build_info.lower()):
				entry['build'] = 'e' + buildNum
			elif ('dp' in user.last_build_info.lower()):
				entry['build'] = 'd' + buildNum
			else:
				entry['build'] = 's' + buildNum


		entry['internal'] = False

		if ((len(user.display_name) == 0) or ('555555' in str(user.phone_number))):
			entry['internal'] = True
		else:
			for phoneNum in constants.DEV_PHONE_NUMBERS:
				if (user.phone_number and phoneNum in str(user.phone_number)):
					entry['internal'] = True
					break

		peopleCounts['photosMetadata'] += user.totalCount
		peopleCounts['photosShared'] += user.thumbsCount
		peopleCounts['friends'] += entry['friendCount']

		swapUserList.append(entry)

	swapUserList = sorted(swapUserList, key=lambda x: x['lastActionTimestamp'], reverse=True)

	# database calls for top tables
	shareInstances = ShareInstance.objects.prefetch_related('users')

	# stats on # of users per share_instance
	userBucket1 = userBucket2 = userBucket3 = userBucket4 = userBucket5 = 0
	
	for si in shareInstances:
		if si.users.count() == 2:
			userBucket1 += 1
		elif si.users.count() == 3:
			userBucket2 += 1
		elif si.users.count() == 4:
			userBucket3 += 1
		elif si.users.count() == 5:
			userBucket4 += 1
		else:
			userBucket5 += 1

	userCounts = dict()
	userCounts['all'] = len(shareInstances)
	userCounts['b1'] = userBucket1
	userCounts['b2'] = userBucket2
	userCounts['b3'] = userBucket3
	userCounts['b4'] = userBucket4
	userCounts['b5'] = userBucket5

	# calculate percentages
	userCounts['b1p'] = float(userBucket1)/float(userCounts['all'])*100.0
	userCounts['b2p'] = float(userBucket2)/float(userCounts['all'])*100.0
	userCounts['b3p'] = float(userBucket3)/float(userCounts['all'])*100.0
	userCounts['b4p'] = float(userBucket4)/float(userCounts['all'])*100.0
	userCounts['b5p'] = float(userBucket5)/float(userCounts['all'])*100.0


	peopleCounts['friends'] = peopleCounts['friends']/2 #dividing by two to count relationships
	peopleCounts['all'] = len(swapUserList)

	statsCounts = dict()
	statsCounts['friendsPerUser'] = float(peopleCounts['friends'])/float(peopleCounts['all'])
	statsCounts['sisPerUser'] = float(userCounts['all'])/float(peopleCounts['all'])
	statsCounts['photosSharedPerUser'] = float(peopleCounts['photosShared'])/float(peopleCounts['all'])
	statsCounts['photosMetadataPerUser'] = float(peopleCounts['photosMetadata'])/float(peopleCounts['all'])
	statsCounts['percentPhotosShared'] = float(peopleCounts['photosShared'])/float(peopleCounts['photosMetadata'])*100.0

	context = {	'swapUserList': swapUserList,
				'userCounts': userCounts,
				'peopleCounts': peopleCounts,
				'statsCounts': statsCounts}

	return render(request, 'admin/userbaseSummary.html', context)

# Helper functions

def setSession(request, userId):
	request.session['userid'] = userId




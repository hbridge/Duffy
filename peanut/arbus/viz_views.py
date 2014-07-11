import os, datetime
import json
from collections import OrderedDict
from datetime import datetime, date
from dateutil.relativedelta import relativedelta
from dateutil import tz
import time, math, urllib

from django.shortcuts import render
from django.http import HttpResponse

from django.template import RequestContext, loader
from django.db.models import Q, Count, Max

from haystack.query import SearchQuerySet

from peanut.settings import constants

from common.models import Photo, User, Classification, NotificationLog

from arbus import image_util, search_util
from arbus.forms import ManualAddPhoto

	
def manualAddPhoto(request):
	form = ManualAddPhoto()

	context = {'form' : form}
	return render(request, 'photos/manualAddPhoto.html', context)

def search(request):
	return render(request, 'photos/search.html')


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

	users = User.objects.filter(product_id=0)

	for user in users:
		entry = dict()
		entry['user'] = user
		if (user.added):
			entry['userCreated'] = user.added.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')

		counts = Photo.objects.filter(user_id=user.id).aggregate(totalCount=Count('id'), thumbsCount=Count('thumb_filename'), 
			photosWithGPS=Count('location_point'), twofishCount=Count('twofishes_data'), fullImagesCount=Count('full_filename'), 
			clusteredCount=Count('clustered_time'), neighborCount=Count('neighbored_time'), overfeatCount=Count('overfeat_data'), 
			classCount=Count('classification_data'), faceCount=Count('faces_data'), lastAdded=Max('added'), lastUpdated=Max('updated'))

		if (counts['totalCount'] > 0):

			entry['lastUploadTime'] = counts['lastAdded'].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
			entry['lastUpdatedTime'] = counts['lastUpdated'].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')

			entry['dbCount'] = counts['totalCount']
			entry['thumbsCount'] = counts['thumbsCount']
			entry['thumbs'] = int(math.floor(entry['thumbsCount']/counts['totalCount']*100))

			if counts['photosWithGPS'] > 0:
				entry['twofishCount'] = counts['photosWithGPS']
				entry['twofish'] = int(math.floor(float(counts['twofishCount'])/float(counts['photosWithGPS'])*100))
			else:
				entry['twofish'] = '-'

			entry['fullimagesCount'] = counts['fullImagesCount']
			entry['fullimages'] = entry['fullimagesCount']*100/counts['totalCount']
			
			entry['clusteredCount'] = counts['clusteredCount']
			entry['clustered'] = entry['clusteredCount']*100/counts['totalCount']

			if (counts['fullImagesCount'] > 0):
				entry['overfeatCount'] = counts['overfeatCount']
				entry['overfeat'] = counts['overfeatCount']*100/counts['fullImagesCount']
			else:
				entry['overfeat'] = 0

			if (counts['fullImagesCount'] > 0):
				entry['classifications'] = counts['classCount']*100/counts['fullImagesCount']
			else:
				entry['classifications'] = 0
				
			entry['faces'] = counts['faceCount']*100/counts['totalCount']

			# Search results count
			searchResults = SearchQuerySet().all().filter(userId=user.id)
			entry['resultsCount'] = searchResults.count()*100/counts['totalCount']


			entry['internal'] = False

			if (user.added == None or len(user.display_name) == 0):
				entry['internal'] = True
			else:
				for phoneid in knownPhoneIds:
					if ((phoneid.lower() in user.phone_id.lower()) or 
						('iphone simulator'.lower() in user.display_name.lower()) or
						('ipad simulator'.lower() in user.display_name.lower())):
						entry['internal'] = True
						break

		arbusList.append(entry)


	users = User.objects.filter(product_id=1)
	strandList = list()

	for user in users:
		entry = dict()
		entry['user'] = user
		if (user.added):
			entry['userCreated'] = user.added.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
		if (user.last_location_timestamp):
			entry['lastLocationTimestamp'] = user.last_location_timestamp.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')

		counts = Photo.objects.filter(user_id=user.id).aggregate(totalCount=Count('id'), thumbsCount=Count('thumb_filename'), 
			photosWithGPS=Count('location_point'), twofishCount=Count('twofishes_data'), fullImagesCount=Count('full_filename'), 
			clusteredCount=Count('clustered_time'), neighborCount=Count('neighbored_time'), lastAdded=Max('added'))

		notifsCounts = NotificationLog.objects.filter(user_id=user.id).aggregate(totalNotifs=Count('id'), lastSent=Max('added'))

		if (counts['totalCount'] > 0):

			entry['dbCount'] = counts['totalCount']
			entry['thumbsCount'] = counts['thumbsCount']
			entry['thumbs'] = int(math.floor(entry['thumbsCount']/counts['totalCount']*100))

			if counts['photosWithGPS'] > 0:
				entry['twofishCount'] = counts['photosWithGPS']
				entry['twofish'] = int(math.floor(float(counts['twofishCount'])/float(counts['photosWithGPS'])*100))
			else:
				entry['twofish'] = '-'
			entry['fullimagesCount'] = counts['fullImagesCount']
			entry['fullimages'] = entry['fullimagesCount']*100/counts['totalCount']

			
			entry['clusteredCount'] = counts['clusteredCount']
			entry['clustered'] = entry['clusteredCount']*100/counts['totalCount']

			if counts['photosWithGPS'] > 0:
				entry['neighbor'] = counts['neighborCount']*100/counts['photosWithGPS']
			else:
				entry['neighbor'] = '-'

			entry['lastUploadTime'] = counts['lastAdded'].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')

			entry['notifications'] = notifsCounts['totalNotifs']
			if notifsCounts['lastSent']:
				entry['lastNotifSent'] = notifsCounts['lastSent'].astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')


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

		strandList.append(entry)


	context = {	'arbusList': arbusList,
				'strandList': strandList}
	return render(request, 'admin/userbaseSummary.html', context)

# Helper functions

def setSession(request, userId):
	request.session['userid'] = userId




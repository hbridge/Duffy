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
from django.db.models import Q

from haystack.query import SearchQuerySet

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
		dbQuery = Photo.objects.filter(user_id=user.id)
		totalCount = dbQuery.count()
		if (totalCount > 0):
			photoSet = dbQuery.order_by('-added')[:1]
			for photo in photoSet:
				entry['lastUploadTime'] = photo.added.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
				break
			photoSet = dbQuery.order_by('-updated')[:1]
			for photo in photoSet:
				entry['lastUpdatedTime'] = photo.updated.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
				break	

			entry['dbCount'] = totalCount
			entry['thumbsCount'] = dbQuery.exclude(thumb_filename=None).count()
			entry['thumbs'] = int(math.floor(entry['thumbsCount']/totalCount*100))
			photosWithGPS = dbQuery.filter((Q(metadata__contains='{GPS}') & Q(metadata__contains='Latitude')) | Q(location_point__isnull=False)).count()

			if photosWithGPS > 0:
				entry['twofishCount'] = photosWithGPS
				entry['twofish'] = int(math.floor(float(dbQuery.exclude(twofishes_data=None).count())/float(photosWithGPS)*100))
			else:
				entry['twofish'] = '-'
			fullimagesCount = dbQuery.exclude(full_filename=None).count()
			entry['fullimagesCount'] = fullimagesCount
			entry['fullimages'] = entry['fullimagesCount']*100/totalCount

			searchResults = SearchQuerySet().all().filter(userId=user.id)
			entry['resultsCount'] = searchResults.count()*100/totalCount
			
			entry['clusteredCount'] = dbQuery.exclude(clustered_time=None).count()
			entry['clustered'] = entry['clusteredCount']*100/totalCount

			if (fullimagesCount > 0):
				count = dbQuery.exclude(overfeat_data=None).count()
				entry['overfeatCount'] = count
				entry['overfeat'] = count*100/fullimagesCount
			else:
				entry['overfeat'] = 0

			if (fullimagesCount > 0):
				entry['classifications'] = dbQuery.exclude(classification_data=None).count()*100/fullimagesCount
			else:
				entry['classifications'] = 0
				
			entry['faces'] = dbQuery.exclude(faces_data=None).count()*100/totalCount
			entry['internal'] = False

			if (user.added == None or len(user.first_name) == 0):
				entry['internal'] = True
			else:
				for phoneid in knownPhoneIds:
					if ((phoneid.lower() in user.phone_id.lower()) or 
						('iphone simulator'.lower() in user.first_name.lower()) or
						('ipad simulator'.lower() in user.first_name.lower())):
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
		dbQuery = Photo.objects.filter(user_id=user.id)
		totalCount = dbQuery.count()
		if (totalCount > 0):
			photoSet = dbQuery.order_by('-added')[:1]
			for photo in photoSet:
				entry['lastUploadTime'] = photo.added.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
				break
			photoSet = dbQuery.order_by('-updated')[:1]
			for photo in photoSet:
				entry['lastUpdatedTime'] = photo.updated.astimezone(to_zone).strftime('%Y/%m/%d %H:%M:%S')
				break	

			entry['dbCount'] = totalCount
			entry['thumbsCount'] = dbQuery.exclude(thumb_filename=None).count()
			entry['thumbs'] = int(math.floor(entry['thumbsCount']/totalCount*100))
			photosWithGPS = dbQuery.filter(location_point__isnull=False).count()

			if photosWithGPS > 0:
				entry['twofishCount'] = photosWithGPS
				entry['twofish'] = int(math.floor(float(dbQuery.exclude(twofishes_data=None).count())/float(photosWithGPS)*100))
			else:
				entry['twofish'] = '-'
			fullimagesCount = dbQuery.exclude(full_filename=None).count()
			entry['fullimagesCount'] = fullimagesCount
			entry['fullimages'] = entry['fullimagesCount']*100/totalCount

			searchResults = SearchQuerySet().all().filter(userId=user.id)
			entry['resultsCount'] = searchResults.count()*100/totalCount
			
			entry['clusteredCount'] = dbQuery.exclude(clustered_time=None).count()
			entry['clustered'] = entry['clusteredCount']*100/totalCount

			entry['notifications'] = NotificationLog.objects.filter(user_id=user.id).count()

			if photosWithGPS > 0:
				entry['neighbor'] = dbQuery.exclude(neighbored_time=None).count()*100/photosWithGPS
			else:
				entry['neighbor'] = '-'

		entry['internal'] = False

		if (len(user.first_name) == 0):
			entry['internal'] = True
		else:
			for phoneid in knownPhoneIds:
				if ((phoneid.lower() in user.phone_id.lower()) or 
					('iphone simulator'.lower() in user.first_name.lower()) or
					('ipad simulator'.lower() in user.first_name.lower())):
					entry['internal'] = True
					break
		strandList.append(entry)


	context = {	'arbusList': arbusList,
				'strandList': strandList}
	return render(request, 'admin/userbaseSummary.html', context)

# Helper functions

def setSession(request, userId):
	request.session['userid'] = userId




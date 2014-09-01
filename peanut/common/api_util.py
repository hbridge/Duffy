import json
import datetime
import pytz
import time

from phonenumber_field.phonenumber import PhoneNumber

from django.http import HttpResponse
from django.contrib.gis.geos import Point

from peanut.settings import constants

from common.models import Photo
from common.serializers import PhotoActionWithUserNameSerializer, PhotoForApiSerializer

class DuffyJsonEncoder(json.JSONEncoder):
	def default(self, obj):
		if isinstance(obj, datetime.datetime):
			return int(time.mktime(obj.timetuple()))

		if isinstance(obj, PhoneNumber):
			return str(obj)

		if isinstance(obj, Point):
			return str(obj)

			
		return json.JSONEncoder.default(self, obj)

"""
	Creates a photoData object which is what holds the photo data in our json object model

	Looks like:

	"user_id": 333,
	"actions": [
		{
		"id": 1,
		"photo": 295253,
		"user": 297,
		"action": "favorite"
		},
		{
		"id": 2,
		"photo": 295253,
		"user": 342,
		"action": "favorite"
		}
	],
	"id": 295253,
	"dist": null,
	"type": "photo",
	"time_taken": 1404933422,
	"display_name": "iPhone Simulator"
"""
def getPhotoObject(entry):
	photoData = {'type': 'photo'}
	photo = entry['photo']

	if (photo.isDbPhoto()):
		photoData.update(PhotoForApiSerializer(photo.getDbPhoto()).data)
	else:
		photoData.update(photo.serialize())

	# Add in extra fields that aren't a part of the SimplePhoto model
	if 'dist' in entry:
		photoData['dist'] = entry['dist']
	
	if 'actions' in entry:
		photoData['actions'] = [PhotoActionWithUserNameSerializer(photoAction).data for photoAction in entry['actions']]
	
	return photoData


"""
	Called from api_views, turns groups (by month or something else) into sections
	  that is converted to json and returned to the user

	Limit the number of objects we add in by 'num'
	
	Takes as input:
	groupings = [
					{
						'title': string,
						'clusters': 
							[
								[
									{'photo': SimplePhoto, 'dist': distance}
								],
								[
									{'photo': SimplePhoto},
									{'photo': SimplePhoto}
								]
							]
						'docs': [
							{'photo': SimplePhoto},
							{'photo': SimplePhoto}
						]
					}
				]

"""
def turnFormattedGroupsIntoSections(formattedGroups, num):
	result = list()
	lastDate = None
	count = 0
	for group in formattedGroups:
		section = {'type': 'section', 'title': group['title'], 'subtitle': group['subtitle'], 'id': group['id'], 'objects': list()}
		mostRecentPhotoDate = None
		for cluster in group['clusters']:
			if len(cluster) == 1:
				photoData = getPhotoObject(cluster[0])
				section['objects'].append(photoData)

				if not mostRecentPhotoDate or photoData['time_taken'] > mostRecentPhotoDate:
					mostRecentPhotoDate = photoData['time_taken']
			else:
				clusterObj = {'type': 'cluster', 'objects': list()}
				for entry in cluster:
					photoData = getPhotoObject(entry)
					clusterObj['objects'].append(photoData)
					
					if not mostRecentPhotoDate or photoData['time_taken'] > mostRecentPhotoDate:
						mostRecentPhotoDate = photoData['time_taken']
				section['objects'].append(clusterObj)

			count += 1
			if count == num:
				if mostRecentPhotoDate:
					section['expire_time'] = mostRecentPhotoDate + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)

				result.append(section)
				return result
		if ('docs' in group and len(group['docs']) > 0):
			docObj = {'type': 'docstack', 'title': 'Your docs', 'objects': list()}
			for entry in group['docs']:
				photoData = getPhotoObject(entry)
				docObj['objects'].append(photoData)
			section['objects'].append(docObj)

		if mostRecentPhotoDate:
			section['expire_time'] = mostRecentPhotoDate + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)

		result.append(section)
	return result

def getRequestData(request):
	if request.method == 'GET':
		data = request.GET
	elif request.method == 'POST':
		data = request.POST

	return data

def returnFailure(response, msg):
	response['result'] = False
	response['debug'] = msg
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Get a datetime object or a int() Epoch timestamp and return a
	pretty string like 'an hour ago', 'Yesterday', '3 months ago',
	'just now', etc

	From: http://stackoverflow.com/questions/1551382/user-friendly-time-format-in-python
"""
def prettyDate(time=False):
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	if type(time) is int:
		diff = now - datetime.datetime.fromtimestamp(time)
	elif isinstance(time, datetime.datetime):
		diff = now - time
	elif not time:
		diff = now - now
	second_diff = diff.seconds
	day_diff = diff.days

	if day_diff < 0:
		return ''

	if day_diff == 0:
		if second_diff < 60:
			return "just now"
		if second_diff < 120:
			return "a min ago"
		if second_diff < 3600:
			return str(second_diff / 60) + " mins ago"
		if second_diff < 7200:
			return "an hour ago"
		if second_diff < 86400:
			return str(second_diff / 3600) + " hours ago"
	if day_diff == 1:
		return "Yesterday"
	if day_diff < 7:
		return str(day_diff) + " days ago"
	if day_diff < 14:
		return "a week ago"
	if day_diff < 31:
		return str(day_diff / 7) + " weeks ago"
	if day_diff < 60:
		return "a month ago"
	if day_diff < 365:
		return str(day_diff / 30) + " months ago"
	if day_diff < 730:
		return "a year ago"
	return str(day_diff / 365) + " years ago"

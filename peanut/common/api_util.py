import json
import datetime
import time

from django.http import HttpResponse
from phonenumber_field.phonenumber import PhoneNumber

from common.models import Photo
from common.serializers import PhotoActionWithUserNameSerializer, PhotoForApiSerializer

class DuffyJsonEncoder(json.JSONEncoder):
	def default(self, obj):
		if isinstance(obj, datetime.datetime):
			return int(time.mktime(obj.timetuple()))

		if isinstance(obj, PhoneNumber):
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
def turnGroupsIntoSections(groupings, num):
	result = list()
	lastDate = None
	count = 0
	for group in groupings:
		section = {'type': 'section', 'title': group['title'], 'objects': list()}
		for cluster in group['clusters']:
			if len(cluster) == 1:
				photoData = getPhotoObject(cluster[0])
				section['objects'].append(photoData)
				lastDate = photoData['time_taken']
			else:
				clusterObj = {'type': 'cluster', 'objects': list()}
				for entry in cluster:
					photoData = getPhotoObject(entry)
					clusterObj['objects'].append(photoData)
					lastDate = photoData['time_taken']
				section['objects'].append(clusterObj)

			count += 1
			if count == num:
				result.append(section)
				return lastDate, result
		if ('docs' in group and len(group['docs']) > 0):
			docObj = {'type': 'docstack', 'title': 'Your docs', 'objects': list()}
			for entry in group['docs']:
				photoData = getPhotoObject(entry)
				docObj['objects'].append(photoData)
			section['objects'].append(docObj)
		result.append(section)
	return lastDate, result

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

import json
import datetime
import time

from django.http import HttpResponse
from phonenumber_field.phonenumber import PhoneNumber

from common.models import Photo

class DuffyJsonEncoder(json.JSONEncoder):
	def default(self, obj):
		if isinstance(obj, datetime.datetime):
			return int(time.mktime(obj.timetuple()))

		if isinstance(obj, PhoneNumber):
			return str(obj)
			
		return json.JSONEncoder.default(self, obj)

"""
	Takes in a dict of the type:

	'name': [description1, description2]
"""
def formatErrors(errors):
	a = list()
	for key, value in errors.iteritems():

		if isinstance(value, list):
			a.append({"name": key, "decription": value[0]})
		else:
			a.append({"name": key, "decription": value})

	return json.dumps(a, cls=DuffyJsonEncoder)

def getPhotoObject(entry):
	photoData = {'type': 'photo'}
	photo = entry['photo']

	photoData.update(photo.serialize())

	if 'dist' in entry:
		photoData['dist'] = entry['dist']
		
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

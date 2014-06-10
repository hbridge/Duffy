import json
import datetime
import time

from common.models import Photo
from common.serializers import SmallPhotoSerializer

class TimeEnabledEncoder(json.JSONEncoder):
	def default(self, obj):
		if isinstance(obj, datetime.datetime):
			return int(time.mktime(obj.timetuple()))

		return json.JSONEncoder.default(self, obj)
		
def getPhotoObject(entry):
	photoData = {'type': 'photo'}
	if 'solr_photo' in entry:
		# This is a solr photo
		photo = entry['solr_photo']
		
		photoData.update({
			'id': photo.photoId,
			'time_taken': photo.timeTaken
		})
		
		return photoData
	elif 'db_photo' in entry:
		# This is a database photo
		photo = entry['db_photo']
		
		photoData.update(SmallPhotoSerializer(photo).data)
		return photoData
	else:
		return None

"""
	Turns groups by month, called from gallery_util and turns it into sections
	  that is converted to json and returned to the user

	Limit the number of objects we add in by 'num'

	Takes in solr_photo or db_photo
	
	Takes as input:
	groupings = [
					{
						'title': string,
						'clusters': 
							[
								[
									{'solr_photo': Photo}
								],
								[
									{'solr_photo': Photo},
									{'solr_photo': Photo}
								]
							]
						'docs': [
							{'solr_photo': Photo},
							{'solr_photo': Photo}
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

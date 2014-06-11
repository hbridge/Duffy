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
	photo = entry['photo']

	if hasattr(photo, 'photoId'):
		# This is a solr photo
		
		photoData.update({
			'id': photo.photoId,
			'time_taken': photo.timeTaken
		})
		
		return photoData
	else:
		# This is a database photo
		
		photoData.update(SmallPhotoSerializer(photo).data)
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
									{'photo': Photo or SolrPhoto}
								],
								[
									{'photo': Photo or SolrPhoto},
									{'photo': Photo or SolrPhoto}
								]
							]
						'docs': [
							{'photo': Photo or SolrPhoto},
							{'photo': Photo or SolrPhoto}
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

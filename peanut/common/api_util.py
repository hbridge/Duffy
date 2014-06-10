from common.models import Photo
from common.serializers import SmallPhotoSerializer

def getPhotoObject(solrOrDBPhoto):
	photoData = {'type': 'photo'}
	if (solrOrDBPhoto.photoId):
		# This is a solr photo
		photoData.update({
			'id': solrOrDBPhoto.photoId
		})
		
		return photoData 
	else:
		# This is a database photo
		return photoData.update(SmallPhotoSerializer(solrOrDBPhoto).data)

"""
	Turns groups by month, called from gallery_util and turns it into sections
	  that is converted to json and returned to the user

	Limit the number of objects we add in by 'num'

	Takes as input:
	groupings = [
					{
						'title': string,
						'clusters': 
							[
								[
									{'photo': Photo}
								],
								[
									{'photo': Photo},
									{'photo': Photo}
								]
							]
						'docs': [
							{'photo': Photo},
							{'photo': Photo}
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
				photo = cluster[0]['photo']
				section['objects'].append(getPhotoObject(photo))
				lastDate = photo.timeTaken
			else:
				clusterObj = {'type': 'cluster', 'objects': list()}
				for entry in cluster:
					photo = entry['photo']
					clusterObj['objects'].append(getPhotoObject(photo))
					lastDate = photo.timeTaken
				section['objects'].append(clusterObj)

			count += 1
			if count == num:
				result.append(section)
				return lastDate, result
		if (len(group['docs']) > 0):
			docObj = {'type': 'docstack', 'title': 'Your docs', 'objects': list()}
			for entry in group['docs']:
				photo = entry['photo']
				docObj['objects'].append(getPhotoObject(photo))
			section['objects'].append(docObj)
		result.append(section)
	return lastDate, result

from photos.models import Photo, Similarity

from collections import OrderedDict

from datetime import datetime, date
from dateutil.relativedelta import relativedelta

from haystack.query import SearchQuerySet
from django.db.models import Q

"""
	Splits a DB query of Photo objects into timeline view with headers and set of photo clusters
"""

def splitPhotosFromDBbyMonth(userId, photoSet=None, groupThreshold=None):
	if (photoSet == None):
		photoSet = Photo.objects.filter(user_id=userId)

	if (groupThreshold == None):
		groupThreshold = 11

	dates = photoSet.datetimes('time_taken', 'month')
	
	photos = list()

	entry = dict()
	entry['date'] = 'Undated'
	entry['mainPhotos'] = list(photoSet.filter(time_taken=None)[:groupThreshold])
	entry['subPhotos'] = list(photoSet.filter(time_taken=None)[groupThreshold:])
	entry['count'] = len(entry['subPhotos'])
	if (len(entry['mainPhotos']) > 0):
		photos.append(entry)

	for date in dates:
		entry = dict()
		entry['date'] = date.strftime('%b %Y')
		entry['mainPhotos'] = list(photoSet.exclude(time_taken=None).exclude(time_taken__lt=date).exclude(time_taken__gt=date+relativedelta(months=1)).order_by('time_taken')[:groupThreshold])
		entry['subPhotos'] = list(photoSet.exclude(time_taken=None).exclude(time_taken__lt=date).exclude(time_taken__gt=date+relativedelta(months=1)).order_by('time_taken')[groupThreshold:])
		entry['count'] = len(entry['subPhotos'])
		photos.append(entry)

	return photos

"""
	Splits a SearchQuerySet into timeline view with headers and set of photo clusters
"""

def splitPhotosFromIndexbyMonth(userId, photoSet=None, threshold=None):
	if (photoSet == None):
		photoSet = 	SearchQuerySet().filter(userId=userId)

	if (threshold == None):
		threshold = 75

	dateFacet = photoSet.date_facet('timeTaken', start_date=date(1900,1,1), end_date=date(2014,5,1), gap_by='month').facet('timeTaken', mincount=1, limit=-1, sort=False)
	facetCounts = dateFacet.facet_counts()
	
	photos = list()

	del facetCounts['dates']['timeTaken']['start']
	del facetCounts['dates']['timeTaken']['end']
	del facetCounts['dates']['timeTaken']['gap']

	od = OrderedDict(sorted(facetCounts['dates']['timeTaken'].items()))
	for dateKey, countVal in od.items():
		entry = dict()
		startDate = datetime.strptime(dateKey[:-1], '%Y-%m-%dT%H:%M:%S')
		entry['date'] = startDate.strftime('%b %Y')
		newDate = startDate+relativedelta(months=1)
		entry['clusterList'] = getClusters(photoSet.exclude(timeTaken__lt=startDate).exclude(timeTaken__gt=newDate).order_by('timeTaken'), threshold)
		entry['count'] = len(entry['clusterList'])
		photos.append(entry)
		
	return photos

"""
	Returns clusters for a set of photos based on the threshold
"""


def getClusters(photoSet, threshold):

	# get a list of Similarity objects matching the current set of photos
	photoSetList = list()
	photoIdToPhotoDict = dict()
	for result in photoSet:
		try:
			photo = Photo.objects.get(id=result.photoId)
			photoSetList.append(photo)
			photoIdToPhotoDict[result.photoId] = photo
		except Photo.DoesNotExist:
			print 'photo not found'

	sims = Similarity.objects.filter(photo_1__in=photoSetList).filter(photo_2__in=photoSetList).order_by('similarity')

	# start building clusters
	'''
	clusterList
		cluster
		   --> photoblocks
		   	   --> entry
		   	       --> photo
		   	       --> dist (shortest distance to any photo in set)
		   	   --> entry
		   	       --> photo
		   	       --> dist (shortest distance to any photo in set)
		   	   --> ...
		   --> count
		cluster
		   --> photoblocks
		   	   --> entry
		   	       --> photo
		   	       --> dist (shortest distance to any photo in set)
		   	   --> ...
		   --> count
	'''
	clusterList = list()

	for result in photoSet:
		if (len(clusterList) == 0):
			# first case
			curCluster = dict()
			curCluster['photoblocks'] = list()
			clusterList.append(curCluster)
			entry = dict()
			entry['photo'] = result
			curCluster['photoblocks'].append(entry)
			curCluster['count'] = 1 # don't include the first picture
			curClusterPhotoList = list()
			curClusterPhotoList.append(photoIdToPhotoDict[result.photoId])
		else:
			curClusterRows = sims.filter(photo_1__in=curClusterPhotoList) | sims.filter(photo_2__in=curClusterPhotoList)
			filterClusterRows = curClusterRows.filter(Q(photo_1=photoIdToPhotoDict[result.photoId]) | Q(photo_2=photoIdToPhotoDict[result.photoId]))
			if (filterClusterRows.count() > 0 and filterClusterRows[0].similarity < threshold):
				# add to cluster
				entry = dict()
				entry['photo'] = result
				entry['dist'] = filterClusterRows[0].similarity
				entry['simrow'] = filterClusterRows[0]
				curCluster['photoblocks'].append(entry)
				curCluster['count'] += 1				
				curClusterPhotoList.append(photoIdToPhotoDict[result.photoId])
			else:
				# no match, start new cluster
				curCluster = dict()
				curCluster['photoblocks'] = list()				
				clusterList.append(curCluster)
				entry = dict()
				entry['photo'] = result
				curCluster['photoblocks'].append(entry)
				curCluster['count'] = 1
				curClusterPhotoList = list()
				curClusterPhotoList.append(photoIdToPhotoDict[result.photoId])
	return clusterList






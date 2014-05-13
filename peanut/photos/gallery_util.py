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
	Fetch all Similarities for the given photo ideas then put into a hash table keyed on the id
	Note:  Make sure to refer to photo_1_id instead of photo_1.id to avoid an extra lookup
"""
def getSimCache(photoIds):
	simCache = dict()

	simResults = Similarity.objects.filter(photo_1__in=photoIds).filter(photo_2__in=photoIds).order_by('similarity')

	for sim in simResults:
		id1 = sim.photo_1_id
		id2 = sim.photo_2_id

		if (id1 not in simCache):
			simCache[id1] = dict()
		simCache[id1][id2] = sim
	return simCache

"""
	Splits a SearchQuerySet into timeline view with headers and set of photo clusters
"""

def splitPhotosFromIndexbyMonth(userId, solrPhotoSet=None, threshold=75, dupThreshold=40):
	if (solrPhotoSet == None):
		solrPhotoSet = 	SearchQuerySet().filter(userId=userId)

	# Buckets all the search queries by month
	dateFacet = solrPhotoSet.date_facet('timeTaken', start_date=date(1900,1,1), end_date=date(2016,1,1), gap_by='month').facet('timeTaken', mincount=1, limit=-1, sort=False)
	facetCounts = dateFacet.facet_counts()

	photoIds = list()
	for solrPhoto in solrPhotoSet:
		photoIds.append(solrPhoto.photoId)

	# Fetch all the similarities at once so we can process in memory
	simCache = getSimCache(photoIds)
	
	del facetCounts['dates']['timeTaken']['start']
	del facetCounts['dates']['timeTaken']['end']
	del facetCounts['dates']['timeTaken']['gap']

	photos = list()
	od = OrderedDict(sorted(facetCounts['dates']['timeTaken'].items()))

	for dateKey, countVal in od.items():
		entry = dict()
		startDate = datetime.strptime(dateKey[:-1], '%Y-%m-%dT%H:%M:%S')
		entry['date'] = startDate.strftime('%b %Y')
		newDate = startDate+relativedelta(months=1)

		filteredPhotos = solrPhotoSet.exclude(timeTaken__lt=startDate).exclude(timeTaken__gt=newDate).order_by('timeTaken')
		
		entry['clusterList'] = getClusters(filteredPhotos, threshold, dupThreshold, simCache)
		photos.append(entry)

	return photos

"""
	Look up in the hash table cache for the Similarity
"""
def getSim(solrPhoto1, solrPhoto2, simsCache):
	if (solrPhoto1.photoId < solrPhoto2.photoId):
		lowerPhotoId = int(solrPhoto1.photoId)
		higherPhotoId = int(solrPhoto2.photoId)
	else:
		lowerPhotoId = int(solrPhoto2.photoId)
		higherPhotoId = int(solrPhoto1.photoId)

	if (lowerPhotoId in simsCache):
		if (higherPhotoId in simsCache[lowerPhotoId]):
			return simsCache[lowerPhotoId][higherPhotoId]

	return None

"""
	Searches the given cluster to see what the lowest distance is for the given solrPhoto
	Returns (index of the photo with the lowest distance, the lowest distance)
"""
def getLowestDistance(cluster, solrPhoto, simCache):
	if (len(cluster) == 0):
		return (None, None)

	lowestDist = None
	lowestIndex = None

	for i, entry in enumerate(cluster):
		sim = getSim(entry['photo'], solrPhoto, simCache)
		if (sim):
			dist = sim.similarity
			if (not lowestDist):
				lowestIndex = i
				lowestDist = dist
			elif (dist < lowestDist):
				lowestIndex = i
				lowestDist = dist
			
	return (lowestIndex, lowestDist)

"""
	Adds the given solrPhoto to the cluster, also grabs the sim from the simCache
	and adds that for debugging
"""		
def addToCluster(cluster, solrPhoto, lowestIndex, lowestDist, simCache):
	sim = getSim(solrPhoto, cluster[lowestIndex]['photo'], simCache)
	cluster.append({'photo': solrPhoto, 'dist': lowestDist, 'simrow': sim})

	return cluster

"""
	Returns clusters for a set of photos based on the threshold

	Returns:
	clusterList
		cluster
			--> entry
				--> photo
				--> dist (shortest distance to any photo in set)
			--> entry
				--> photo
				--> dist (shortest distance to any photo in set)
				--> simrow (only for 2nd and later elements)
			--> ...
		cluster
			--> entry
				--> photo
				--> dist (shortest distance to any photo in set)
			--> ...
"""	
def getClusters(solrPhotoSet, threshold, dupThreshold, simCache):
	# get a list of Similarity objects matching the current set of photos
	
	# start building clusters
	clusterList = list()
	solrPhotoSetIter = iter(solrPhotoSet)
	firstPhoto = next(solrPhotoSetIter)
	clusterList.append([{'photo': firstPhoto, 'dist': None}])

	for solrPhoto in solrPhotoSetIter:
		currentCluster = clusterList[-1]
		# For each photo, look at last cluster and see if it belongs
		# If so, add it
		# Else, start a new cluster
		lowestIndex, lowestDist = getLowestDistance(currentCluster, solrPhoto, simCache)
		if (lowestDist):
			if (lowestDist < dupThreshold):
				pass
			elif (lowestDist < threshold):
				addToCluster(currentCluster, solrPhoto, lowestIndex, lowestDist, simCache)
			else:
				clusterList.append([{'photo': solrPhoto, 'dist': None}])
		else:
			clusterList.append([{'photo': solrPhoto, 'dist': None}])
	return clusterList






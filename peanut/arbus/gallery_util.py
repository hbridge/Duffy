from collections import OrderedDict

import datetime
from dateutil.relativedelta import relativedelta

from haystack.query import SearchQuerySet
from django.db.models import Q

from itertools import groupby

from peanut import settings
from common.models import Photo, Similarity
"""
	Fetch all Similarities for the given photo ideas then put into a hash table keyed on the id
	Note:  Make sure to refer to photo_1_id instead of photo_1.id to avoid an extra lookup
"""
def getSimCaches(photoIds):
	simCacheLowHigh = dict()
	simCacheHighLow = dict()

	simResults = Similarity.objects.filter(photo_1__in=photoIds).filter(photo_2__in=photoIds).order_by('similarity')

	for sim in simResults:
		id1 = sim.photo_1_id
		id2 = sim.photo_2_id

		if (id1 not in simCacheLowHigh):
			simCacheLowHigh[id1] = dict()
		simCacheLowHigh[id1][id2] = sim

		if (id2 not in simCacheHighLow):
			simCacheHighLow[id2] = dict()
		simCacheHighLow[id2][id1] = sim


	return (simCacheLowHigh, simCacheHighLow)

"""
	Splits a SearchQuerySet into groups of months as well as clusters the images

	Returns:
	[
	  {
		'title' = "May 2013"
		'clusters' = [
						[
							{
								'photo' = solrPhoto
								'dist' = (shortest distance to any photo in set)
							}
						],
						[
							{
								'photo' = solrPhoto
								'dist' = (shortest distance to any photo in set)
							},
							{
								'photo' = solrPhoto
								'dist' = (shortest distance to any photo in set)
								'simrow' = (only for 2nd and later elements)
							},
						],
					]
	  },
	]

"""
def splitPhotosFromIndexbyMonth(userId, solrPhotoSet, threshold=settings.DEFAULT_CLUSTER_THRESHOLD, dupThreshold=settings.DEFAULT_DUP_THRESHOLD, docResults=None):
	photoIds = list()
	for solrPhoto in solrPhotoSet:
		photoIds.append(solrPhoto.photoId)

	# Fetch all the similarities at once so we can process in memory
	simCaches = getSimCaches(photoIds)
	
	clusters = getClusters(solrPhotoSet, threshold, dupThreshold, simCaches)

	# process docstack results first
	docs = dict()
	if (docResults):
		f = lambda x: x.timeTaken.strftime('%b %Y')
		results = list()
		for key, items in groupby(docResults, f):
			docs[key] = list()
			for item in items:
				docs[key].append({'photo': item, 'dist': None, 'simrows': getAllSims(solrPhoto, simCaches)})

	# process regular photos next
	f = lambda x: x[0]['photo'].timeTaken.strftime('%b %Y')
	results = list()
	for key, items in groupby(clusters, f):
		monthEntry = {'title': key, 'clusters': list(), 'docs': list()}
		for item in items:
			monthEntry['clusters'].append(item)
		if key in docs:
			monthEntry['docs'].extend(docs[key])
		results.append(monthEntry)
	
	return results

"""
	Look up in the hash table cache for the Similarity
"""
def getSim(solrPhoto1, solrPhoto2, simCaches):
	simsCacheLowHigh, simsCacheHighLow = simCaches
	if (solrPhoto1.photoId < solrPhoto2.photoId):
		lowerPhotoId = int(solrPhoto1.photoId)
		higherPhotoId = int(solrPhoto2.photoId)
	else:
		lowerPhotoId = int(solrPhoto2.photoId)
		higherPhotoId = int(solrPhoto1.photoId)

	if (lowerPhotoId in simsCacheLowHigh):
		if (higherPhotoId in simsCacheLowHigh[lowerPhotoId]):
			return simsCacheLowHigh[lowerPhotoId][higherPhotoId]

	return None


def getAllSims(solrPhoto, simCaches):
	sims = list()
	photoId = int(solrPhoto.photoId)
	simsCacheLowHigh, simsCacheHighLow = simCaches

	if (photoId in simsCacheLowHigh):
		for key in simsCacheLowHigh[photoId]:
			sims.append(simsCacheLowHigh[photoId][key])

	if (photoId in simsCacheHighLow):
		for key in simsCacheHighLow[photoId]:
			sims.append(simsCacheHighLow[photoId][key])

	return sims


"""
	Searches the given cluster to see what the lowest distance is for the given solrPhoto
	Returns (index of the photo with the lowest distance, the lowest distance)
"""
def getLowestDistance(cluster, solrPhoto, simCaches):
	if (len(cluster) == 0):
		return (None, None)
		
	lowestDist = None
	lowestIndex = None

	for i, entry in enumerate(cluster):
		sim = getSim(entry['photo'], solrPhoto, simCaches)
		if (sim):
			dist = sim.similarity
			if (not lowestDist):
				lowestIndex = i
				lowestDist = dist
			elif (dist < lowestDist):
				lowestIndex = i
				lowestDist = dist
			
	return (lowestIndex, lowestDist)

def getLongestTimeSince(cluster, solrPhoto):
	longestTime = None
	for i, entry in enumerate(cluster):
		dist = abs(entry['photo'].timeTaken - solrPhoto.timeTaken)
		if not longestTime:
			longestTime = dist
		elif dist > longestTime:
			logestTime = dist
	return longestTime

"""
	Adds the given solrPhoto to the cluster, also grabs the sim from the simCache
	and adds that for debugging
"""		
def addToCluster(cluster, solrPhoto, lowestIndex, lowestDist, simCaches):
	sim = getSim(solrPhoto, cluster[lowestIndex]['photo'], simCaches)
	cluster.append({'photo': solrPhoto, 'dist': lowestDist, 'simrow': sim, 'simrows': getAllSims(solrPhoto, simCaches)})

	return cluster

"""
	Returns clusters for a set of photos based on the threshold

	Returns:
	clusterList (list)
		cluster (list)
			--> entry (dict)
				--> photo (solrPhoto)
				--> dist (shortest distance to any photo in set)
			--> entry
				--> photo (solrPhoto)
				--> dist (shortest distance to any photo in set)
				--> simrow (only for 2nd and later elements)
			--> ...
		cluster
			--> entry
				--> photo
				--> dist (shortest distance to any photo in set)
			--> ...
"""	
def getClusters(solrPhotoSet, threshold, dupThreshold, simCaches):
	# get a list of Similarity objects matching the current set of photos
	
	# start building clusters
	clusterList = list()
	if len(solrPhotoSet) == 0:
		return clusterList
	solrPhotoSetIter = iter(solrPhotoSet)
	firstPhoto = next(solrPhotoSetIter)
	clusterList.append([{'photo': firstPhoto, 'dist': None, 'simrows': getAllSims(firstPhoto, simCaches)}])

	for solrPhoto in solrPhotoSetIter:
		currentCluster = clusterList[-1]
		# For each photo, look at last cluster and see if it belongs
		# If so, add it
		# Else, start a new cluster
		lowestIndex, lowestDist = getLowestDistance(currentCluster, solrPhoto, simCaches)
		longestTime = getLongestTimeSince(currentCluster, solrPhoto)

		if (lowestDist != None):
			if (lowestDist < dupThreshold):
				pass
			elif (lowestDist < threshold and longestTime < datetime.timedelta(minutes=settings.DEFAULT_MINUTES_TO_CLUSTER)):
				addToCluster(currentCluster, solrPhoto, lowestIndex, lowestDist, simCaches)
			else:
				clusterList.append([{'photo': solrPhoto, 'dist': None, 'simrows': getAllSims(solrPhoto, simCaches)}])
		else:
			clusterList.append([{'photo': solrPhoto, 'dist': None, 'simrows': getAllSims(solrPhoto, simCaches)}])
	return clusterList






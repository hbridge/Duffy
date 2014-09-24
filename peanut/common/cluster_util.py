from collections import OrderedDict

import datetime
from dateutil.relativedelta import relativedelta

from haystack.query import SearchQuerySet
from django.db.models import Q

from itertools import groupby

from peanut.settings import constants
from common.models import Photo, Similarity, SimplePhoto

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

	THIS ONLY WORKS FOR SOLR PHOTOS RIGHT NOW
	Can refactor to do either though pretty easily
"""
def splitPhotosFromIndexbyMonth(userId, solrPhotoSet, threshold=constants.DEFAULT_CLUSTER_THRESHOLD, dupThreshold=constants.DEFAULT_DUP_THRESHOLD, docResults=None):
	photoIds = list()
	for solrPhoto in solrPhotoSet:
		photoIds.append(solrPhoto.photoId)

	# Fetch all the similarities at once so we can process in memory
	simCaches = getSimCaches(photoIds)
	
	clusters = getClustersFromPhotos(solrPhotoSet, threshold, dupThreshold, simCaches)

	# process docstack results first
	docs = dict()
	if (docResults):
		f = lambda x: x.timeTaken.strftime('%b %Y')
		results = list()
		for key, solrPhotos in groupby(docResults, f):

			docs[key] = list()
			for solrPhoto in solrPhotos:
				photo = SimplePhoto(solrPhoto)
				docs[key].append({'photo': photo, 'dist': None, 'simrows': getAllSims(photo, simCaches)})

	# process regular photos next
	f = lambda x: x[0]['photo'].time_taken.strftime('%b %Y')
	groupings = list()
	for key, items in groupby(clusters, f):
		monthEntry = {'title': key, 'clusters': list(), 'docs': list()}
		for item in items:
			monthEntry['clusters'].append(item)
		if key in docs:
			monthEntry['docs'].extend(docs[key])
		groupings.append(monthEntry)
	
	return groupings



"""
	Returns clusters for a set of photos based on the threshold

	Can take in a set of SolrPhotos or DBPhotos

	Returns:
	clusterList (list)
		cluster (list)
			--> entry (dict)
				--> photo (SimplePhoto)
				--> dist (shortest distance to any photo in set)
			--> entry
				--> photo (SimplePhoto)
				--> dist (shortest distance to any photo in set)
				--> simrow (only for 2nd and later elements)
			--> ...
		cluster
			--> entry
				--> photo (SimplePhoto)
				--> dist (shortest distance to any photo in set)
			--> ...
"""	
def getClustersFromPhotos(photoSet, threshold, dupThreshold, simCaches):
	# get a list of Similarity objects matching the current set of photos
	
	# start building clusters
	clusterList = list()
	if len(photoSet) == 0:
		return clusterList
		
	photoSetIter = iter(photoSet)
	firstPhoto = SimplePhoto(next(photoSetIter))

	clusterList.append([{'photo': firstPhoto, 'dist': None, 'simrows': getAllSims(firstPhoto, simCaches)}])

	for p in photoSetIter:
		photo = SimplePhoto(p)
		currentCluster = clusterList[-1]
		# For each photo, look at last cluster and see if it belongs
		# If so, add it
		# Else, start a new cluster
		lowestIndex, lowestDist = getLowestDistance(currentCluster, photo, simCaches)
		longestTime = getLongestTimeSince(currentCluster, photo)

		if (lowestDist != None):
			if (lowestDist < dupThreshold):
				pass
			elif (lowestDist < threshold and longestTime < datetime.timedelta(minutes=constants.DEFAULT_MINUTES_TO_CLUSTER)):
				addToCluster(currentCluster, photo, lowestIndex, lowestDist, simCaches)
			else:
				clusterList.append([{'photo': photo, 'dist': None, 'simrows': getAllSims(photo, simCaches)}])
		else:
			clusterList.append([{'photo': photo, 'dist': None, 'simrows': getAllSims(photo, simCaches)}])
	return clusterList



"""
	Fetch all Similarities for the given photo ideas then put into a hash table keyed on the id
	Note:  Make sure to refer to photo_1_id instead of photo_1.id to avoid an extra lookup
"""
def getSimCaches(photoIds):
	simCacheLowHigh = dict()
	simCacheHighLow = dict()

	simResults = Similarity.objects.select_related().filter(photo_1__in=photoIds).filter(photo_2__in=photoIds).order_by('similarity')

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
	Look up in the hash table cache for the Similarity
"""
def getSim(photo1, photo2, simCaches):
	simsCacheLowHigh, simsCacheHighLow = simCaches
	if (photo1.id < photo2.id):
		lowerPhotoId = int(photo1.id)
		higherPhotoId = int(photo2.id)
	else:
		lowerPhotoId = int(photo2.id)
		higherPhotoId = int(photo1.id)

	if (lowerPhotoId in simsCacheLowHigh):
		if (higherPhotoId in simsCacheLowHigh[lowerPhotoId]):
			return simsCacheLowHigh[lowerPhotoId][higherPhotoId]

	return None


def getAllSims(photo, simCaches):
	sims = list()
	photoId = int(photo.id)
	simsCacheLowHigh, simsCacheHighLow = simCaches

	if (photoId in simsCacheLowHigh):
		for key in simsCacheLowHigh[photoId]:
			sims.append(simsCacheLowHigh[photoId][key])

	if (photoId in simsCacheHighLow):
		for key in simsCacheHighLow[photoId]:
			sims.append(simsCacheHighLow[photoId][key])

	return sims


"""
	Searches the given cluster to see what the lowest distance is for the given photo
	Returns (index of the photo with the lowest distance, the lowest distance)
"""
def getLowestDistance(cluster, photo, simCaches):
	if (len(cluster) == 0):
		return (None, None)
		
	lowestDist = None
	lowestIndex = None

	for i, entry in enumerate(cluster):
		sim = getSim(entry['photo'], photo, simCaches)
		if (sim):
			dist = sim.similarity
			if (not lowestDist):
				lowestIndex = i
				lowestDist = dist
			elif (dist < lowestDist):
				lowestIndex = i
				lowestDist = dist
			
	return (lowestIndex, lowestDist)

def getLongestTimeSince(cluster, photo):
	longestTime = None
	for i, entry in enumerate(cluster):
		dist = abs(entry['photo'].time_taken - photo.time_taken)
		if not longestTime:
			longestTime = dist
		elif dist > longestTime:
			logestTime = dist
	return longestTime

"""
	Adds the given photo to the cluster, also grabs the sim from the simCache
	and adds that for debugging
"""		
def addToCluster(cluster, photo, lowestIndex, lowestDist, simCaches):
	sim = getSim(photo, cluster[lowestIndex]['photo'], simCaches)
	cluster.append({'photo': photo, 'dist': lowestDist, 'simrow': sim, 'simrows': getAllSims(photo, simCaches)})

	return cluster





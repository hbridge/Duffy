import os, sys, os.path
import Image
import json
import logging
import datetime
from time import time

from django.utils import timezone

import cv2
import cv2.cv as cv

#TODO(Derek): move this over to our common one
from bulk_update.helper import bulk_update

from peanut.settings import constants
from common.models import Photo, User, Classification, Similarity
from arbus import image_util

### Clustering/deduping functions
"""
	Create similarity rows for a set of db photos

	This finds all the simrows to create and update, then does the actual db work
"""
def createSimsForPhotos(photos, threshold=100):
	if len(photos) == 0:
		return 0

	simRows = list()
	histCache = dict()
	simsToCreate = list()
	simsToUpdate = list()
	photosToUpdate = list()
	
	userPhotoCache = list(Photo.objects.select_related().filter(user=photos[0].user.id).exclude(time_taken=None).exclude(thumb_filename=None).order_by('time_taken'))
	
	# Go through each photo and gather the sim rows
	for photo in photos:
		simRows.extend(getSimRowsForPhoto(photo, histCache, userPhotoCache))
		photo.clustered_time = datetime.datetime.now()
		photosToUpdate.append(photo)

	if (len(simRows) > 0):
		uniqueSimRows = getUniqueSimRows(simRows)
		allIds = getAllPhotoIds(uniqueSimRows)

		# Break apart the sim rows based on what needs creating and what needs updating
		existingSims = Similarity.objects.select_related().filter(photo_1__in=allIds).filter(photo_2__in=allIds)
		(simsToCreate, simsToUpdate) = processWithExisting(existingSims, uniqueSimRows)

		# Do a bulk create for new sim rows
		Similarity.objects.bulk_create(simsToCreate)

		# Update existing sim rows
		if (len(simsToUpdate) == 1):
			simsToUpdate[0].save()
		elif (len(simsToUpdate) > 1):
			bulk_update(simsToUpdate)

	# If we wrote put the Similarities correctly, then update photos to update the clustered_time
	Photo.bulkUpdate(photosToUpdate, ["clustered_time"])

	return len(simsToCreate) + len(simsToUpdate)


def getUniqueSimRows(simRows):
	uniqueSimRows = dict()

	for simRow in simRows:
		id = (simRow.photo_1.id, simRow.photo_2.id)
		if id in uniqueSimRows:
			if simRow.similarity > uniqueSimRows[id]:
				uniqueSimRows[id] = simRow
		else:
			uniqueSimRows[id] = simRow
	return uniqueSimRows.values()
	
def getAllPhotoIds(simRows):
	photoIds = list()
	for simRow in simRows:
		photoIds.append(simRow.photo_1)
		photoIds.append(simRow.photo_2)

	return set(photoIds)

def processWithExisting(existingSims, newSims):
	simsToCreate = list()
	simsToUpdate = list()

	for newSim in newSims:
		found = False
		for existingSim in existingSims:
			if newSim.photo_1 == existingSim.photo_1 and newSim.photo_2 == existingSim.photo_2:
				if newSim.similarity > existingSim.similarity:
					existingSim.similarity = newSim.similarity
					simsToUpdate.append(existingSim)
				found = True

		if not found:
			simsToCreate.append(newSim)

	return (simsToCreate, simsToUpdate)

"""
	Get a list of photos that are "near" this photo: Within DEFAULT_MINUTES_TO_CLUSTER minutes of this photo
"""
def getNearbyPhotos(photo, range, userPhotoCache):
	for i, p in enumerate(userPhotoCache):
		if photo == p:

			nearbyPhotos = list()
			timeTaken = p.time_taken # current photo's time tkaen

			if i > 0:
				for a in xrange(i, 0, -1):
					if (userPhotoCache[a-1].time_taken+datetime.timedelta(seconds=60*constants.DEFAULT_MINUTES_TO_CLUSTER)>timeTaken):
						nearbyPhotos.append(userPhotoCache[a-1])
					else:
						break

			if i < len(userPhotoCache)-1:
				for a in xrange(i+1, len(userPhotoCache)):
					if (userPhotoCache[a].time_taken-datetime.timedelta(seconds=60*constants.DEFAULT_MINUTES_TO_CLUSTER)<timeTaken):
						nearbyPhotos.append(userPhotoCache[a])
					else:
						break
				
			return nearbyPhotos
	return []

"""
	Gets sim rows for the given photo.
"""
def getSimRowsForPhoto(photo, histCache, userPhotoCache, threshold=100):
	if (photo.thumb_filename == None):
		return 0

	if (photo.time_taken == None and photo.added == None):
		# if no timestamp exists, then skip the photo for clustering
		return 0

	# get current photo's histogram
	curHist = getSpatialHistFromCache(photo, histCache)
	if (curHist == None):
		return 0

	nearbyPhotos = getNearbyPhotos(photo, 5, userPhotoCache)

	simRows = genSimilarityRowsFromList(photo, histCache, nearbyPhotos, threshold)
	return simRows

"""
	Compares curPhoto to each photo in photoList and adds a row if under threshold
	Returns True if any rows were added (useful to figure out if you need to keep going)

"""

def genSimilarityRowsFromList(curPhoto, histCache, photoList, threshold):
	simRows = list()
	for photo in photoList:
		dist = compHist(getSpatialHistFromCache(curPhoto, histCache),getSpatialHistFromCache(photo, histCache))
		if (dist < threshold):
			simRow = genSimilarityRow(curPhoto, photo, dist)
			if simRow:
				simRows.append(simRow)
	return simRows

"""
	Adds/updates a specific row to similarity table, if it doesn't exist.
	Note: photoId1 should be less than photoId2 
"""
def genSimilarityRow(photo1, photo2, sim):
	if (photo1.id == photo2.id):
		print "Error: Can't add same photo for both photo_1 and photo_2 in Similarity table"
		return None

	if (photo1.id > photo2.id):
		tempPhoto = photo1
		photo1 = photo2
		photo2 = tempPhoto
	
	simRow = Similarity(photo_1 = photo1,
						photo_2 = photo2,
						user = photo1.user,
						similarity = int(sim))

	return simRow

""" 
	Returns true if a row of two photos already exists in the table
"""
def doesSimilarityRowAlreadyExists(photo1, photo2):
	if (photo1.id >= photo2.id):
		tempPhoto = photo1
		photo1 = photo2
		photo2 = tempPhoto
	sim = Similarity.objects.all().filter(photo_1=photo1).filter(photo_2=photo2) 
	if (sim.count() > 0):
		return True
	return False

### Clustering: Histogram functions

"""
	Get histogram from cache. If it doesn't exist, generate and add to cache and return it
"""
def getSpatialHistFromCache(photo, histCache):
	if (photo.id not in histCache):
		histCache[photo.id] = getSpatialHist(photo)
	return histCache[photo.id]

"""
	Get a photo's spatial histogram using opencv's ELBP method
"""
def getSpatialHist(photo):
	if (photo.full_filename and not photo.thumb_filename):
		image_util.createThumbnail(photo) # check in case thumbnails haven't been created

	photo_color = cv2.imread(photo.getThumbPath())
	photo_color = cv2.resize(photo_color,(156,156))
	photo_gray = cv2.cvtColor(photo_color, cv.CV_RGB2GRAY)
	photo_gray = cv2.equalizeHist(photo_gray)

	lbp = cv2.elbp(photo_gray, 1, 8)
	return cv2.spatial_histogram(lbp, 256, 8, 8, True)

"""
	Returns distance between two histograms 
	Lower is better 
"""
def compHist(h1, h2):
	# Change this to easily change the distance metric everywhere
	return compHistChiSqr(h1, h2)

"""
	Returns distance between two histograms using ChiSqr
	Scale: 0 - infinity (lower is better)
"""
def compHistChiSqr(h1, h2):
	return cv2.compareHist(h1, h2, cv.CV_COMP_CHISQR)

"""
	Returns distance between two histograms using Intersection
	Scale: 0 - 100 (lower is better)
"""
def compHistIntersect(h1, h2):
	return 100*(1 - cv2.compareHist(h1, h2, cv.CV_COMP_INTERSECT))

"""
	Returns distance between two histograms using Correlation
	Scale: 0 - 100 (lower is a better match)
"""
def compHistCorrel(h1, h2):
	return 50*(1 - cv2.compareHist(h1, h2, cv.CV_COMP_CORREL))

"""
	Returns distance between two histograms using Bhattacharya
	Scale: 0 - 100 (lower is a better match)
"""
def compHistBhat(h1, h2):
	return 50*(1 - cv2.compareHist(h1, h2, cv.CV_COMP_BHATTACHARYYA))


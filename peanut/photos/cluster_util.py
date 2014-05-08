import os, sys, os.path
import Image
import json
from datetime import datetime

from django.utils import timezone

from peanut import settings
from photos.models import Photo, User, Classification, Similarity
from photos import image_util
import cv2
import cv2.cv as cv

from bulk_update.helper import bulk_update

### Clustering/deduping functions

"""
	Cluster for multiple photos
"""
def addToClustersBulk(photos, threshold=100):
	histCache = dict()
	count = 0
	for photo in photos:
		count += addToClusters(photo, histCache)
		photo.clustered_time = datetime.now()
	if (len(photos) > 0):
		if (len(photos) == 1):
			photos[0].save()
		else:
			bulk_update(photos)
	return count

"""
	Populates similarity table for a new photo
"""
def addToClusters(photo, histCache, threshold=100):

	if (photo.thumb_filename == None):
		return 0

	if (photo.time_taken == None and photo.added == None):
		# if no timestamp exists, then skip the photo for clustering
		return 0

	photos = list()

	# get a list of photos that are "near" this photo: meaning pre and post in the timeline
	if (photo.time_taken == None):
		# for undated photos, use 'added' which is the upload time
		photos = list(Photo.objects.all().filter(user_id=photo.user.id).filter(time_taken=None).exclude(id=photoId).exclude(added__gt=photo.added).exclude(thumb_filename=None).order_by('-added')[:5])
		photos.extend(list(Photo.objects.all().filter(user_id=photo.user.id).filter(time_taken=None).exclude(id=photoId).exclude(added__lt=photo.added).exclude(thumb_filename=None).order_by('added')[:5]))
	else:
		photos = list(Photo.objects.all().filter(user_id=photo.user.id).exclude(time_taken__gt=photo.time_taken).exclude(time_taken=None).exclude(id=photo.id).exclude(thumb_filename=None).order_by('-time_taken')[:5])
		photos.extend(list(Photo.objects.all().filter(user_id=photo.user.id).exclude(time_taken__lt=photo.time_taken).exclude(time_taken=None).exclude(id=photo.id).exclude(thumb_filename=None).order_by('time_taken')[:5]))

	# get current photo's histogram
	curHist = getSpatialHistFromCache(photo, histCache)
	if (curHist == None):
		return 0

	count = genSimilarityRowsFromList(photo, histCache, photos, threshold)
	return count

"""
	Continues to follow a resulting query of photos until one of them isn't similar enough
	Returns count of DB operations: adds or modified
"""

def genSimilarityRowsFromDBQuery(curPhoto, histCache, photoQuery, threshold, batch=None):

	if (batch == None):
		batch = 5

	simRows = list()
	tempRows = list()

	keepGoing = True
	loop = 0
	while keepGoing == True:
		keepGoing = False
		loop += 1
		# pick them in batches to process
		photoBatch = list(photoQuery[((loop-1)*batch):(batch*loop)])
		tempRows = genSimilarityRowsFromList(curPhoto, histCache, photoBatch)
		if (len(tempRows) > 0):
			simRows.extend(tempRows)
			keepGoing = True


"""
	Compares curPhoto to each photo in photoList and adds a row if under threshold
	Returns True if any rows were added (useful to figure out if you need to keep going)

"""

def genSimilarityRowsFromList(curPhoto, histCache, photoList, threshold):

	count = 0
	for photo in photoList:
		#TODO(Aseem): In theory you can do a check here to see if the row already exists
		# But, that stops the search because it doesn't extend beyond these 5
		#if (doesSimilarityRowAlreadyExists(curPhoto, photo)):
		#	returnVal = True
		#	continue
		dist = compHist(getSpatialHistFromCache(curPhoto, histCache),getSpatialHistFromCache(photo, histCache))
		if (dist < threshold):
			count += genSimilarityRow(curPhoto, photo, dist)
	return count

"""
	Adds/updates a specific row to similarity table, if it doesn't exist.
	Note: photoId1 should be less than photoId2 
"""
def genSimilarityRow(photo1, photo2, sim):
	if (photo1.id == photo2.id):
		print "Error: Can't add same photo for both photo_1 and photo_2 in Similarity table"
		return 0

	if (photo1.id > photo2.id):
		tempPhoto = photo1
		photo1 = photo2
		photo2 = tempPhoto
	
	sim = int(sim)
	
	simQuery= Similarity.objects.all().filter(photo_1=photo1).filter(photo_2=photo2)

	if (simQuery.count() == 0):
		simRow = Similarity(	photo_1 = photo1,
								photo_2 = photo2,
								similarity = sim)
	elif (simQuery.count() == 1):
		if (simQuery[0].similarity <= sim):
			return 0
		else:
			simRow = simQuery[0]
			simRow.similarity = sim
	else:
		print "Error: Found multiple rows with photoId1: {0} and photoId2: {1}".format(photo1.id, photo2.id)
		return 0

	simRow.save()
	return 1

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

	origPath = '/home/derek/user_data/' + str(photo.user.id) + '/'

	if (photo.full_filename and not photo.thumb_filename):
		image_util.createThumbnail(photo) # check in case thumbnails haven't been created

	photo_color = cv2.imread(origPath+photo.thumb_filename)
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


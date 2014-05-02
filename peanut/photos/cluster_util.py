import os, sys, os.path
import Image
import pyexiv2
import exifread
import json
from datetime import datetime

from django.utils import timezone

from peanut import settings
from photos.models import Photo, User, Classification, Similarity
from photos import image_util
import cv2
import cv2.cv as cv

### Clustering/deduping functions

"""
	Populates similarity table for a new photo
"""
def addToClusters(photo, threshold=None):

	if (photo.thumb_filename == None):
		return 0

	if (threshold == None):
		threshold = 100

	if (photo.time_taken == None and photo.added == None):
		# handling case before 'added' field was in the database
		# if no timestamp exists, then skip the photo for clustering
		return 0

	# get a list of photos that are "near" this photo: meaning pre and post in the timeline
	if (photo.time_taken == None):
		# for undated photos, use 'added' which is the upload time
		photoQueryPre = Photo.objects.all().filter(user_id=photo.user.id).filter(time_taken=None).exclude(id=photoId).exclude(added__gt=photo.added).order_by('-added')[:20]
		photoQueryPost = Photo.objects.all().filter(user_id=photo.user.id).filter(time_taken=None).exclude(id=photoId).exclude(added__lt=photo.added).order_by('added')[:20]
	else:
		photoQueryPre = Photo.objects.all().filter(user_id=photo.user.id).exclude(time_taken__gt=photo.time_taken).exclude(time_taken=None).exclude(id=photo.id).order_by('-time_taken')[:20]
		photoQueryPost = Photo.objects.all().filter(user_id=photo.user.id).exclude(time_taken__lt=photo.time_taken).exclude(time_taken=None).exclude(id=photo.id).order_by('time_taken')[:20]

	# get current photo's histogram
	curHist = getSpatialHist(photo)
	if (curHist == None):
		return 0

	genSimilarityRowsFromDBQuery(photo, curHist, photoQueryPre, threshold)
	genSimilarityRowsFromDBQuery(photo, curHist, photoQueryPost, threshold)


"""
	Continues to follow a resulting query of photos until one of them isn't similar enough
	Returns count of DB operations: adds or modified
"""

def genSimilarityRowsFromDBQuery(curPhoto, curHist, photoQuery, threshold, batch=None):

	if (batch == None):
		batch = 5

	keepGoing = True
	loop = 0
	while keepGoing == True:
		keepGoing = False
		loop += 1
		# pick them in batches to process
		photoBatch = list(photoQuery[((loop-1)*batch):(batch*loop)])
		if (genSimilarityRowsFromList(curPhoto, curHist, photoBatch, threshold)):
			keepGoing = True


"""
	Compares curPhoto to each photo in photoList and adds a row if under threshold
	Returns True if any rows were added (useful to figure out if you need to keep going)

"""

def genSimilarityRowsFromList(curPhoto, curHist, photoList, threshold):
	returnVal = False
	for photo in photoList:
		if (doesSimilarityRowAlreadyExists(curPhoto, photo)):
			returnVal = True
			continue
		dist = getSimilarityFromHistAndPhoto(curHist, photo)
		if (dist < threshold):
			if (addSimilarityRow(curPhoto, photo, dist)):
				returnVal = True
	return returnVal

"""
	Adds/updates a specific row to similarity table, if it doesn't exist.
	Note: photoId1 should be less than photoId2 
"""
def addSimilarityRow(photo1, photo2, sim):
	if (photo1.id == photo2.id):
		print "Error: Can't add same photo for both photo_1 and photo_2 in Similarity table"
		return False

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
		if (simQuery[0].similarity == sim):
			return False
		else:
			simRow = simQuery[0]
			simRow.similarity = sim
		return False
	else:
		print "Error: Found multiple rows with photoId1: {0} and photoId2: {1}".format(photo1.id, photo2.id)
		return False

	simRow.save()
	
	return True

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
	Returns distance between two photos when given one hist and one photo Id 
"""		
def getSimilarityFromHistAndPhoto(hist1, photo2):
	return compHist(hist1, getSpatialHist(photo2))


"""
	Returns distance between two histograms. Repetitive to function below.
"""		
def getSimilarityFromHists(hist1, hist2):
	return compHist(hist1, hist2)


"""
	Calculates histograms and returns distance between two photos, when 
	given only their photo Ids
"""		
def getSimilarityFromPhotos(photo1, photo2):
	return compHist(getSpatialHist(photo1), getSpatialHist(photo2))

"""
	Get a photo's spatial histogram using opencv's ELBP method
"""
def getSpatialHist(photo):

	origPath = '/home/derek/user_data/' + str(photo.user.id) + '/'

	if (photo.full_filename and not photo.thumb_filename):
		image_util.createThumbnail(photo) # check in case thumbnails haven't been created

	photo_color = cv2.imread(origPath+photo.thumb_filename)
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


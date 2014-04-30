import os, sys, os.path
import Image
import pyexiv2
import exifread
import json
from datetime import datetime

from django.utils import timezone

from peanut import settings
from photos.models import Photo, User, Classification, Similarity
import cv2
import cv2.cv as cv

### Clustering functions

"""
	Populates similarity table for a new photo
"""
def addToClusters(photoId, threshold=None):
	try:
		curPhoto = Photo.objects.get(id=photoId)
		userId = curPhoto.user.id
	except Photo.DoesNotExist:
		print "addToClusters: PhotoId {0} not found".format(photoId)
		return 0

	# check to see if photo has time_taken field. If not, ignore it.
	if (curPhoto.new_filename == None):
		return 0

	if (threshold == None):
		threshold = 100

	# get a list of photos that are "near" this photo: meaning pre and post in the timeline
	if (curPhoto.time_taken == None):
		# for undated photos, use upload time
		photoQueryPre = Photo.objects.all().filter(user_id=userId).filter(time_taken=None).exclude(id=photoId).exclude(added__gt=curPhoto.upload_date).order_by('-added')[:20]
		photoQueryPost = Photo.objects.all().filter(user_id=userId).filter(time_taken=None).exclude(id=photoId).exclude(added__lt=curPhoto.upload_date).order_by('added')[:20]
	else:
		photoQueryPre = Photo.objects.all().filter(user_id=userId).exclude(time_taken__gt=curPhoto.time_taken).exclude(time_taken=None).exclude(id=photoId).order_by('-time_taken')[:20]
		photoQueryPost = Photo.objects.all().filter(user_id=userId).exclude(time_taken__lt=curPhoto.time_taken).exclude(time_taken=None).exclude(id=photoId).order_by('time_taken')[:20]

	# get current photo's histogram
	curHist = getSpatialHist(photoId)
	if (curHist == None):
		return 0

	rowCount = genSimilarityRowsFromDBQuery(curPhoto, curHist, photoQueryPre, threshold)
	rowCount += genSimilarityRowsFromDBQuery(curPhoto, curHist, photoQueryPost, threshold)

	return rowCount


"""
	Continues to follow a resulting query of photos until one of them isn't similar enough

	Returns count of DB operations: adds or modified
"""

def genSimilarityRowsFromDBQuery(curPhoto, curHist, photoQuery, threshold, batch=None):

	if (batch == None):
		batch = 5

	rowCount = 0
	keepGoing = True
	loop = 0
	while keepGoing == True:
		keepGoing = False
		loop += 1
		# pick them in batches to process
		photoBatch = list(photoQuery[((loop-1)*batch):(batch*loop)])
		dbOps = genSimilarityRowsFromList(curPhoto, curHist, photoBatch, threshold)
		if (dbOps > 0):
			rowCount += dbOps
			keepGoing = True
	return rowCount


"""
	Compares curPhoto to each photo in photoList and adds a row if under threshold

	Returns count of DB operations: adds or modified

"""

def genSimilarityRowsFromList(curPhoto, curHist, photoList, threshold):
	count = 0
	for photo in photoList:
		#print "photo.id: {0} | time_taken: {1}".format(str(photo.id), photo.time_taken)
		if (doesSimilarityRowAlreadyExists(curPhoto, photo)):
			continue
		dist = getSimilarityFromHistAndPhoto(curHist, photo.id)
		if (dist < threshold):
			if (addSimilarityRow(curPhoto, photo, dist)):
				count += 1
	return count

"""
	Adds/updates a specific row to similarity table, if it doesn't exist.
	Note: photoId1 < photoId2 or it'll error
"""
def addSimilarityRow(photo1, photo2, sim):
	if (photo1.id == photo2.id):
		print "Error: Can't add same photo for both photo_1 and photo_2 in Similarity table"
		return False

	if (photo1.id >= photo2.id):
		tempPhoto = photo1
		photo1 = photo2
		photo2 = tempPhoto
	
	#print "ROW: Photo1: {0} | Photo2: {1} | sim: {2}".format(photo1.id, photo2.id, sim)
	'''	
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
	else:
		print "Error: Found multiple rows with photoId1: {0} and photoId2: {1}".format(photo1.id, photo2.id)
		return False

	simRow.save()
	'''
	return True

""" 
	Returns true if a row of two photos already exists in the table
"""
def doesSimilarityRowAlreadyExists(photo1, photo2):
	if (photo1.id >= photo2.id):
		tempPhoto = photo1
		photo1 = photo2
		photo2 = tempPhoto
	if (Similarity.objects.all().filter(photo_1=photo1).filter(photo_2=photo2).count() > 0):
		return True
	return False

### Clustering: Histogram functions

"""
	Returns distance between two photos when given one hist and one photo Id 
"""		
def getSimilarityFromHistAndPhoto(hist1, photoId2):
	return compHist(hist1, getSpatialHist(photoId2))


"""
	Returns distance between two histograms. Repetitive to function below.
"""		
def getSimilarityFromHists(hist1, hist2):
	return compHist(hist1, hist2)


"""
	Calculates histograms and returns distance between two photos, when 
	given only their photo Ids
"""		
def getSimilarityFromPhotoIds(photoId1, photoId2):
	return compHist(getSpatialHist(photoId1), getSpatialHist(photoId2))

"""
	Get a photo's spatial histogram using opencv's ELBP method
"""
def getSpatialHist(photoId):
	try:
		photo = Photo.objects.get(id=photoId)
		userId = photo.user.id
	except Photo.DoesNotExist:
		return None

	origPath = '/home/derek/user_data/' + str(userId) + '/'

	# Check to make sure that a thumbnail exists
	photo_thumbnail = imageThumbnail(str(photo.id)+'.jpg', 156, userId)
	if (photo_thumbnail == None):
		print "No thumbnail found for userId/photoId: {0}/{1}".format(userId, photoId)
		return None
	else:
		photo_color = cv2.imread(origPath+photo_thumbnail)
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
	Scale: 0 - infinity (lower the better match)
"""
def compHistChiSqr(h1, h2):
	return cv2.compareHist(h1, h2, cv.CV_COMP_CHISQR)

"""
	Returns distance between two histograms using Intersection
	Scale: 0 - 100 (lower the better match)
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


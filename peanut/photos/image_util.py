import os, sys, os.path
import Image
import pyexiv2
import exifread
import json
from datetime import datetime

from django.utils import timezone

from peanut import settings
from photos.models import Photo, User, Classification
import cv2
import cv2.cv as cv


"""
	Generates a thumbnail of the given image to the given size
	Creates a new file in the same directory as the existing filename of the format:
	PHOTOID-thumb-SIZE.jpg
"""
def createThumbnail(photo):
	if photo.full_filename:
		thumbFilePath = photo.getThumbPath()
		fullFilePath = photo.getFullPath()

		if (os.path.isfile(thumbFilePath)):
			if not photo.thumb_filename:
				photo.thumb_filename = photo.getThumbFilename()
				photo.save()
			return photo.getThumbFilename()

		if(resizeImage(fullFilePath, thumbFilePath, settings.THUMBNAIL_SIZE, True, False)):
			photo.thumb_filename = photo.getThumbFilename()
			photo.save()
			print "generated thumbnail: '%s" % thumbFilePath
		else:
			print "cannot create thumbnail for '%s'" % fullFilePath
	else:
		return None


"""
	Generates a thumbnail of the given image to the given size
	Creates a new file in the same directory as the existing filename of the format:
	PHOTOID-thumb-SIZE.jpg

	TODO(derek):  remove this and move to createThumbnail
"""
def imageThumbnail(photoFname, size, userId):
	path = '/home/derek/user_data/' + str(userId) + '/'
	newFilename = str.split(str(photoFname), '.')[0] + "-thumb-" + str(size) + '.jpg'
	outfilePath = path + newFilename

	if (os.path.isfile(outfilePath)):
		return newFilename

	infilePath = path + str(photoFname)

	if(resizeImage(infilePath, outfilePath, size, True, False)):
		print "generated thumbnail: '%s" % outfilePath
	else:
		print "cannot create thumbnail for '%s'" % infilePath

"""
	Does image resizes and creates a new file (JPG) of the specified size
"""
def resizeImage(origFilepath, newFilepath, size, crop, copyExif):
	try:
		im = Image.open(origFilepath)

		#calc ratios and new min size
		wratio = (size/float(im.size[0])) #width check
		hratio = (size/float(im.size[1])) #height check

		if (hratio > wratio):
			newSize = hratio*im.size[0], hratio*im.size[1]
		else:
			newSize = wratio*im.size[0], wratio*im.size[1]		
		im.thumbnail(newSize, Image.ANTIALIAS)

		# setup the crop to size x size image
		if (crop):
			if (hratio > wratio):
				buffer = int((im.size[0]-size)/2)
				im = im.crop((buffer, 0, (im.size[0]-buffer), size))			
			else:
				buffer = int((im.size[1]-size)/2)
				im = im.crop((0, buffer, size, (im.size[1] - buffer)))
		
		im.load()
		im.save(newFilepath, "JPEG")

		if (copyExif):
			# This part copies over the EXIF information to the new image
			oldmeta = pyexiv2.ImageMetadata(origFilepath)
			oldmeta.read()

			newmeta = pyexiv2.ImageMetadata(newFilepath)
			newmeta.read()

			oldmeta.copy(newmeta)
			newmeta.write()

		return True
	except IOError:
		print("IOError in resizeImage for %s" % origFilepath)
		return False


"""
	This looks at the metadata for the photo and the photo itself to see if it can figure out the time time.
	First it looks in the Exif Metadata, this comes from the iPhone
	Then, it looks in the file EXIF data

	Returns a datetime object which can be put straight into the database
"""
def getTimeTaken(metadataJson, origFilename, photoPath):
	# first see if the data is in the metadata json
	if (metadataJson):
		metadata = json.loads(metadataJson)
		if "{Exif}" in metadata:
			if "DateTimeOriginal" in metadata["{Exif}"]:
				timeStr = metadata["{Exif}"]["DateTimeOriginal"]
				dt = datetime.strptime(timeStr, "%Y:%m:%d %H:%M:%S")
				return dt

		if "{DFCameraRollExtras}" in metadata:
			if "DateTimeCreated" in metadata["{DFCameraRollExtras}"]:
				timeStr = metadata["{DFCameraRollExtras}"]["DateTimeCreated"]
				dt = datetime.strptime(timeStr, "%Y:%m:%d %H:%M:%S")
				return dt
							
	# If not, check the file's EXIF data
	f = open(photoPath, 'rb')
	tags = exifread.process_file(f)

	if "EXIF DateTimeOriginal" in tags:
		origTime = tags["EXIF DateTimeOriginal"]
		dt = datetime.strptime(str(origTime), "%Y:%m:%d %H:%M:%S")
		return dt

	try:
		filenameNoExt = os.path.splitext(os.path.basename(origFilename))[0]
		dt = datetime.strptime(filenameNoExt, "%Y-%m-%d %H.%M.%S")
		return dt
	except ValueError:
		pass

	return None

def processUploadedPhoto(photo, origFileName, tempFilepath):
	im = Image.open(tempFilepath)
	(width, height) = im.size

	if ((width == 156 and height == 156) or (width == 157 and height == 157)):
		os.rename(tempFilepath, photo.getThumbPath())
		photo.thumb_filename = photo.getFullFilename()
	else:
		# Must put this in first since getFullfilename needs it
		photo.orig_filename = origFileName
		photo.full_filename = photo.getFullFilename()

		os.rename(tempFilepath, photo.getFullPath())
		
		photo.save()

		createThumbnail(photo)

"""
	Utility method to add a photo for a user.  Takes in original path (probably uploaded), file info,
	and metadata about the photo.  It then saves assigns the photo a new id, renames it, adds it to the database
	then tries to populate the time_taken and location_city fields

	TODO(derek):  Remove this and rely upon proccessUploadedPhoto and REST API
"""
def addPhoto(user, origPath, localFilepath, metadata, locationData, iPhoneFaceboxesTopleft):
	photo = Photo(	user = user,
					location_data = locationData,
					orig_filename = origPath,
					metadata = metadata,
					iphone_faceboxes_topleft = iPhoneFaceboxesTopleft)
	photo.save()

	base, origFilename = os.path.split(origPath)
	filenameNoExt, fileExtension = os.path.splitext(origPath)
	newFilename = str(photo.id) + fileExtension

	userDataPath = os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, str(user.id))
	newFilePath = os.path.join(userDataPath, newFilename)

	photo.full_filename = newFilename

	os.rename(localFilepath, newFilePath)

	timeTaken = getTimeTaken(metadata, origFilename, newFilePath)
	if (timeTaken):
		photo.time_taken = timeTaken

	photo.save()

	# last step: generate a thumbnail
	imageThumbnail(photo.full_filename, 156, user.id)

"""
	Moves an uploaded file to a new destination
"""
def writeOutUploadedFile(uploadedFile, newFilePath):
	print("Writing to " + newFilePath)

	with open(newFilePath, 'wb+') as destination:
		for chunk in uploadedFile.chunks():
			destination.write(chunk)


### Functions related to finding duplicates and similar photos

"""
	Returns the distance between two photos
"""

def getSimilarity(photoId1, photoId2, userId):
	return compHist(getSpatialHist(photoId1, userId), getSpatialHist(photoId2, userId))


"""
	Get a photo's spatial histogram using opencv's ELBP method
"""
def getSpatialHist(photoId, userId):
	origPath = '/home/derek/user_data/' + str(userId) + '/'
	photo_color = cv2.imread(origPath + str(photoId) + '-thumb-156.jpg')
	photo_gray = cv2.cvtColor(photo_color, cv.CV_RGB2GRAY)
	photo_gray = cv2.equalizeHist(photo_gray)

	lbp = cv2.elbp(photo_gray, 1, 8)
	return cv2.spatial_histogram(lbp, 256, 8, 8, True)

"""
	Returns distance between two histograms
"""
def compHist(h1, h2):
	return cv2.compareHist(h1, h2, cv.CV_COMP_CHISQR)


import os, sys, os.path
import Image
import pyexiv2
import exifread
import json
import tempfile
import logging
from datetime import datetime

from django.utils import timezone

from peanut import settings
from photos.models import Photo, User, Classification, Similarity
import cv2
import cv2.cv as cv

from bulk_update.helper import bulk_update

logger = logging.getLogger(__name__)

"""
	Generates a thumbnail of the given image to the given size
	Creates a new file in the same directory as the existing filename of the format:
	PHOTOID-thumb-SIZE.jpg
"""
def createThumbnail(photo):
	if photo.full_filename:
		thumbFilePath = photo.getDefaultThumbPath()
		fullFilePath = photo.getDefaultFullPath()

		if (os.path.isfile(thumbFilePath)):
			if not photo.thumb_filename:
				photo.thumb_filename = photo.getDefaultThumbFilename()
				photo.save()
			return photo.getDefaultThumbFilename()

		if(resizeImage(fullFilePath, thumbFilePath, settings.THUMBNAIL_SIZE, True, False)):
			photo.thumb_filename = photo.getDefaultThumbFilename()
			photo.save()
			logger.info("generated thumbnail: '%s" % thumbFilePath)
		else:
			logger.info("cannot create thumbnail for '%s'" % fullFilePath)
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
	infilePath = path + str(photoFname)
	
	if (not os.path.isfile(infilePath)):
		logger.info("File not found: '%s'" % infilePath)
		return None

	if (os.path.isfile(outfilePath)):
		return newFilename

	if(resizeImage(infilePath, outfilePath, size, True, False)):
		logger.info("generated thumbnail: '%s" % outfilePath)
		return newFilename
	else:
		logger.info("cannot create thumbnail for '%s'" % infilePath)

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

def processUploadedPhoto(photo, origFileName, tempFilepath, bulk=False):
	im = Image.open(tempFilepath)
	(width, height) = im.size

	if ((width == 156 and height == 156) or (width == 157 and height == 157)):
		os.rename(tempFilepath, photo.getDefaultThumbPath())
		photo.thumb_filename = photo.getDefaultThumbFilename()

		if bulk:
			return photo
		else:
			photo.save()
	else:
		# Must put this in first since getFullfilename needs it
		photo.orig_filename = origFileName
		photo.full_filename = photo.getDefaultFullFilename()

		os.rename(tempFilepath, photo.getDefaultFullPath())
		
		# Don't worry about bulk here since that's only used for thumbnails
		photo.save()

		createThumbnail(photo)

def handleUploadedImage(request, fileKey, photo):
	if fileKey in request.FILES:
		tempFilepath = tempfile.mktemp()
 
		writeOutUploadedFile(request.FILES[fileKey], tempFilepath)
		processUploadedPhoto(photo, request.FILES[fileKey].name, tempFilepath)
	else:
		logger.error("File not found in request: " + fileKey)


def handleUploadedImagesBulk(request, photos):
	photosToUpdate = list()
	for photo in photos:
		tempFilepath = tempfile.mktemp()

		if photo.file_key in request.FILES:
			writeOutUploadedFile(request.FILES[photo.file_key], tempFilepath)
			updatedPhoto = processUploadedPhoto(photo, request.FILES[photo.file_key].name, tempFilepath, bulk=True)
			
			if not updatedPhoto.time_taken:
				updatedPhoto.time_taken = getTimeTaken(updatedPhoto.metadata, updatedPhoto.orig_filename, updatedPhoto.getThumbPath())
				logger.debug("Didn't find time_taken, looked myself and found %s" % (updatedPhoto.time_taken))
	
			photosToUpdate.append(updatedPhoto)
		else:
			logger.error("Tried to look for key: %s in FILES and didn't find" % photo.file_key)


	if (len(photosToUpdate) == 1):
		photosToUpdate[0].save()
	else:
		logger.info("Updating %s photos in db" % (len(photosToUpdate)))
		bulk_update(photosToUpdate)

	if (len(request.FILES) != len(photosToUpdate)):
		logger.error("Have request with %s files and only %s photos updated" % (len(request.FILES), len(photosToUpdate)))
		
	return photosToUpdate

"""
	Moves an uploaded file to a new destination
"""
def writeOutUploadedFile(uploadedFile, newFilePath):
	with open(newFilePath, 'wb+') as destination:
		for chunk in uploadedFile.chunks():
			destination.write(chunk)


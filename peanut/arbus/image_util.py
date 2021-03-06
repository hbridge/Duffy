import os, sys, os.path
from PIL import Image
from PIL.ExifTags import TAGS, GPSTAGS
import pyexiv2
import json
import tempfile
import logging
from datetime import datetime

from django.core.files.storage import default_storage
from django.utils import timezone

import cv2
import cv2.cv as cv

from bulk_update.helper import bulk_update

from peanut.settings import constants
from common.models import Photo, User, Classification, Similarity

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

		s3ThumbFilePath = '/'.join([photo.user.getUserDataId(),photo.getDefaultThumbFilename()])
		if(resizeImage(fullFilePath, thumbFilePath, s3ThumbFilePath, constants.THUMBNAIL_SIZE, True, False)):
			photo.thumb_filename = photo.getDefaultThumbFilename()
			photo.save()
			logger.info("generated thumbnail: '%s" % thumbFilePath)
		else:
			logger.info("cannot create thumbnail for '%s'" % fullFilePath)
	else:
		return None

"""
	Does image resizes and creates a new file (JPG) of the specified size
"""
def resizeImage(origFilepath, newFilepath, s3FilePath, size, crop, copyExif):
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
		copyFileToS3(newFilepath, s3FilePath)

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


# copied from https://gist.github.com/erans/983821
def getExifData(photo):
	exif_data = {}

	if not photo.getFullPath():
		return exif_data

	"""Returns a dictionary from the exif data of an PIL Image item. Also converts the GPS Tags"""
	image = Image.open(photo.getFullPath())
	info = image._getexif()

	if info:
		for tag, value in info.items():
			decoded = TAGS.get(tag, tag)
			if decoded == "GPSInfo":
				gps_data = {}
				for t in value:
					sub_decoded = GPSTAGS.get(t, t)
					gps_data[sub_decoded] = value[t]
 
				exif_data[decoded] = gps_data
			else:
				exif_data[decoded] = value
 
	return exif_data


"""
	This looks at the metadata for the photo and the photo itself to see if it can figure out the time time.
	First it looks in the Exif Metadata, this comes from the iPhone
	Then, it looks in the file EXIF data

	Returns a datetime object which can be put straight into the database

"""
def getTimeTakenFromExtraData(photo, tryFile=False):
	# first see if the data is in the metadata json
	if (photo.metadata):
		metadata = json.loads(photo.metadata)
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

	if tryFile:
		exif = getExifData(photo)

		if "DateTimeOriginal" in exif:
			origTime = exif["DateTimeOriginal"]
			dt = datetime.strptime(str(origTime), "%Y:%m:%d %H:%M:%S")
			return dt

	try:
		if photo.orig_filename:
			filenameNoExt = os.path.splitext(os.path.basename(photo.orig_filename))[0]
			dt = datetime.strptime(filenameNoExt, "%Y-%m-%d %H.%M.%S")
			return dt
	except ValueError:
		pass

	return None

def processUploadedPhoto(photo, origFileName, tempFile, bulk=False):
	im = Image.open(tempFile)
	(width, height) = im.size
	if ((width == 156 and height == 156) or (width == 157 and height == 157)):
		os.system('mv %s %s' % (tempFile.name, photo.getDefaultThumbPath()))
		copyFileToS3(photo.getDefaultThumbPath(), '/'.join([photo.user.getUserDataId(),photo.getDefaultThumbFilename()]))
		photo.thumb_filename = photo.getDefaultThumbFilename()

		if not bulk:
			photo.save()
	else:
		# Must put this in first since getFullfilename needs it
		photo.orig_filename = origFileName
		photo.full_filename = photo.getDefaultFullFilename()

		os.system('mv %s %s' % (tempFile.name, photo.getDefaultFullPath()))
		copyFileToS3(photo.getDefaultFullPath(), '/'.join([photo.user.getUserDataId(),photo.getDefaultFullFilename()]))	

		im = Image.open(photo.getDefaultFullPath())

		for orientation in TAGS.keys():
			if (TAGS[orientation]=='Orientation'): 
				break

		e = im._getexif()
		if (e is not None):
			exif=dict(e.items())

			if exif[orientation] == 6 or exif[orientation] == 8: 
				photo.full_width = im.size[1]
				photo.full_height = im.size[0]
			else:
				photo.full_width = im.size[0]
				photo.full_height = im.size[1]
		
		# Don't worry about bulk here since that's only used for thumbnails
		photo.save()

		if not photo.thumb_filename:
			createThumbnail(photo)

def handleUploadedImage(request, fileKey, photo):
	if fileKey in request.FILES:
		tempFile = tempfile.NamedTemporaryFile()
 
		writeOutUploadedFile(request.FILES[fileKey], tempFile)
		processUploadedPhoto(photo, request.FILES[fileKey].name, tempFile)
	else:
		logger.warning("File not found in request: " + fileKey)
		logger.warning(request.FILES)


def handleUploadedImagesBulk(request, photos):
	count = 0
	for photo in photos:
		if photo.file_key:
			tempFile = tempfile.NamedTemporaryFile()
			if photo.file_key in request.FILES:
				writeOutUploadedFile(request.FILES[photo.file_key], tempFile)
				processUploadedPhoto(photo, request.FILES[photo.file_key].name, tempFile, bulk=True)
				
				logger.debug("Processed photo file, now called %s %s" % (photo.thumb_filename, photo.full_filename))
				count += 1
				
	return count
"""
	Moves an uploaded file to a new destination
"""
def writeOutUploadedFile(uploadedFile, newFile):
	newFile.seek(0)
	for chunk in uploadedFile.chunks():
		newFile.write(chunk)
	# bringing the seek back to first bit to read it later, since we are passing around File objects.
	newFile.seek(0)

"""
	Copies a file to s3
"""
def copyFileToS3(localFilePath, s3FilePath):
	localFile = open(localFilePath, 'rb')
	with default_storage.open(s3FilePath, 'wb+') as destination:
		destination.write(localFile.read())
	localFile.close()
	if default_storage.exists(s3FilePath):
		logger.info("Uploaded file to s3: %s"%(s3FilePath))
	else:
		logger.error("Failed to upload file to s3: %s"%(s3FilePath))



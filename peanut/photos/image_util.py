import os, sys, os.path
import Image
import exifread
import json
from datetime import datetime

from django.utils import timezone

from peanut import settings
from photos.models import Photo, User, Classification

"""
	Generates a thumbnail of the given image to the given size
	Creates a new file in the same directory as the existing filename of the format:
	PHOTOID-thumb-SIZE.jpg
"""
def imageThumbnail(photoFname, size, userId):
	# comment this out when production server runs it
	#path = '/home/aseem/userdata/' + str(userId) + '/images/'
	path = '/home/derek/user_data/' + str(userId) + '/'
	newFilename = str.split(str(photoFname), '.')[0] + "-thumb-" + str(size) + '.jpg'
	outfilePath = path + newFilename

	if (os.path.isfile(outfilePath)):
		return newFilename
	
	try:
		infile = path + str(photoFname)
		im = Image.open(infile)

		#calc ratios and new min size
		wratio = (size/float(im.size[0])) #width check
		hratio = (size/float(im.size[1])) #height check

		if (hratio > wratio):
			newSize = hratio*im.size[0], hratio*im.size[1]
		else:
			newSize = wratio*im.size[0], wratio*im.size[1]		
		im.thumbnail(newSize, Image.ANTIALIAS)

		# setup the crop to size x size image
		
		if (hratio > wratio):
			buffer = int((im.size[0]-size)/2)
			im = im.crop((buffer, 0, (im.size[0]-buffer), size))			
		else:
			buffer = int((im.size[1]-size)/2)
			im = im.crop((0, buffer, size, (im.size[1] - buffer)))
		
		im.load()
		im.save(outfilePath, "JPEG")
		print "generated thumbnail: '%s" % outfilePath
		return newFilename
	except IOError:
		print "cannot create thumbnail for '%s'" % infile
		return None

"""
	This looks at the metadata for the photo and the photo itself to see if it can figure out the time time.
	First it looks in the Exif Metadata, this comes from the iPhone
	Then, it looks in the file EXIF data

	Returns a datetime object which can be put straight into the database
"""
def getTimeTaken(metadataJson, photoPath):
	# first see if the data is in the metadata json
	if (metadataJson):
		metadata = json.loads(metadataJson)
		for key in metadata.keys():
			if key == "{Exif}":
				for a in metadata[key].keys():
					if a == "DateTimeOriginal":
						dt = datetime.strptime(metadata[key][a], "%Y:%m:%d %H:%M:%S")
						return dt
							
	# If not, check the file's EXIF data
	f = open(photoPath, 'rb')
	tags = exifread.process_file(f)

	if "EXIF DateTimeOriginal" in tags:
		origTime = tags["EXIF DateTimeOriginal"]
		dt = datetime.strptime(str(origTime), "%Y:%m:%d %H:%M:%S")
		return dt

	return None

"""
	If present, grab the city field from the photo's location data
"""
def getLocationCity(locationJson):
	if (locationJson):
		locationData = json.loads(locationJson)

		if ('address' in locationData):
			address = locationData['address']
			if ('City' in address):
				city = address['City']
				return city
	return None


"""
	Utility method to add a photo for a user.  Takes in original path (probably uploaded), file info,
	and metadata about the photo.  It then saves assigns the photo a new id, renames it, adds it to the database
	then tries to populate the time_taken and location_city fields
"""
def addPhoto(user, origPath, fileObj, metadata, locationData, iPhoneFaceboxesTopleft):
	photo = Photo(	user = user,
					location_data = locationData,
					orig_filename = origPath,
					upload_date = timezone.now(),
					metadata = metadata,
					iphone_faceboxes_topleft = iPhoneFaceboxesTopleft)
	photo.save()

	filename, fileExtension = os.path.splitext(origPath)
	newFilename = str(photo.id) + fileExtension

	userDataPath = os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, str(user.id))
	newFilePath = os.path.join(userDataPath, newFilename)

	photo.new_filename = newFilename

	handleUploadedFile(fileObj, newFilePath)

	timeTaken = getTimeTaken(metadata, newFilePath)
	if (timeTaken):
		photo.time_taken = timeTaken

	city = getLocationCity(locationData)
	if (city):
		photo.location_city = city

	photo.save()


"""
	Moves an uploaded file to a new destination
"""
def handleUploadedFile(uploadedFile, newFilePath):
	print("Writing to " + newFilePath)

	with open(newFilePath, 'wb+') as destination:
		for chunk in uploadedFile.chunks():
			destination.write(chunk)

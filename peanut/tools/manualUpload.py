#!/usr/bin/python
import requests
import sys, os, getopt
import json
import tempfile
import pyexiv2

import Image


"""
	Does image resizes and creates a new file (JPG) of the specified size
	Copy and pasted from image_util
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

def getFilesAndData(rootdir, userId, maxNum):
	size = 569

	files = dict()
	dataArray = list()
	filepathsDict = dict()

	for subdir, dirs, filenames in os.walk(rootdir):
		for filename in filenames:
			name, ext = os.path.splitext(filename)

			if (ext in [".jpg", ".JPG"]):
				keyName = "key" + str(len(dataArray))
				filepath = os.path.join(rootdir, filename)
				filepathsDict[keyName] = filepath

				tmpfile = os.path.join(tempfile.gettempdir(), filename)

				if (resizeImage(filepath, tmpfile, size, False, True)):
					files[keyName] = open(tmpfile, "r")

					data = dict()
					data["file_key"] = keyName
					data["user"] = userId
					data["is_local"] = 0
					
					dataArray.append(data)

			if len(dataArray) == maxNum:
				return (files, dataArray, filepathsDict)

	return (files, dataArray, filepathsDict)

"""
	Script to manually upload files from local computer

	This creates a newly resized image to the size like the iPhone sends over, then uses the bulk
	add api for the specified user
"""
def main(argv):
	url = "http://asood123.no-ip.biz:8000/api/photos/bulk/"
	maxNum = 10
	imagePath = None
	userId = None

	try:
		opts, args = getopt.getopt(argv,"hu:d:n:",["userId="])
	except getopt.GetoptError:
		print 'manualUpload.py -u <userId> -d <imagePath> -n <maxNum>'
		sys.exit(2)

	for opt, arg in opts:
		if opt == '-h':
			print 'injestFiles.py -u <userId> -d <imagePath> -n <maxNum>'
			sys.exit()
		elif opt in '-u':
			userId = int(arg)
		elif opt in '-d':
			imagePath = arg
		elif opt in '-n':
			maxNum = int(arg)

	if not imagePath or not userId:
		print ("Pelase enter -u userId and -d imagePath")
	
	(files, dataArray, filepathsDict) = getFilesAndData(imagePath, userId, maxNum)

	while (len(dataArray) > 0):
		payload = {'bulk_photos': json.dumps(dataArray)}
		responseJson = requests.post(url, files=files, data=payload)

		print responseJson.text
		response = json.loads(responseJson.text)
		for photoResponse in response:
			keyName = photoResponse["file_key"]
			filepath = filepathsDict[keyName]

			print "Removing %s" % (filepath)
			os.remove(filepath)

		(files, dataArray, filepathsDict) = getFilesAndData(imagePath, userId, maxNum)
		

if __name__ == "__main__":
	main(sys.argv[1:])
import sys, os
import time, datetime
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.db.models import Count
from photos.models import Photo, User
from peanut import settings

import cv2
import cv2.cv as cv

class FaceDetector:
	cascade = None

	def __init__(self):
		# cascade list for face detection
		cascadePath = os.path.split(os.path.abspath(__file__))[0] + '/cascades/'
		cascadeFFDefault =  cascadePath + 'haarcascades/haarcascade_frontalface_alt.xml'
		self.cascade = cv2.CascadeClassifier(cascadeFFDefault)

	"""
		Returns set of rectangles with faces found. 
		Format: [[x, y, width, height]]
		Ex: [[244 694  50  50] # rect 1 starts at coordinates (244, 694) with width and height of 50px
			 [229 647  57  57]] # rect 2
	"""
	def findFacesWithOpenCV(self, photo):
		# Make sure a photo full or thumb exists
		if (photo.full_filename):
			photoPath = photo.getFullPath()
			minSize = (30,30)
		elif (photo.thumb_filename):
			photoPath = photo.getThumbPath()
			minSize = (20,20)
		else:
			return 0

		pColor = cv2.imread(photoPath)
		pGray = cv2.cvtColor(pColor, cv.CV_RGB2GRAY)
		clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
		pGray = clahe.apply(pGray)

		# detect front faces
		faceRects = self.detect(pGray, minSize=minSize)
		return faceRects

	def detect(	self,
				img,
				scaleFactor=1.1,
				minNeighbors=4,
				minSize=(30, 30),
				flags=cv.CV_HAAR_SCALE_IMAGE):
		rects = self.cascade.detectMultiScale(img,
											scaleFactor=scaleFactor,
											minNeighbors=minNeighbors,
											minSize=minSize,
											flags=flags)
		if len(rects) == 0:
			return []
		else:
			ret = list()
			for rect in rects:
				ret.append(rect.tolist())
		return ret

def main(argv):

	userId = 138
		
	photos = list(Photo.objects.select_related().filter(user_id=userId).exclude(thumb_filename=None).order_by('time_taken')[:100])

	faceRects = dict()

	faceDetector = FacesUtil()
	for photo in photos:
		faceRects[photo] = faceDetector.findFacesWithOpenCV(photo)
		print faceRects[photo] 
		if len(faceRects[photo]) > 0:
			print "PhotoId: {0}".format(photo.id)
			print str(faceRects[photo])



if __name__ == "__main__":
	main(sys.argv[1:])
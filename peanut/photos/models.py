import os
import json

from django.db import models

from peanut import settings

# Create your models here.
class User(models.Model):
	first_name = models.CharField(max_length=100, null=True)
	last_name = models.CharField(max_length=100, null=True)
	phone_id = models.CharField(max_length=100)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	"""
		Returns back the full localfile path where the user's photos are located
		So:  /home/blah/1/
	"""
	def getUserDataPath(self):
		return os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, str(self.id))

	def __unicode__(self):
		return self.first_name + " " + self.last_name + " - " + self.phone_id


class Photo(models.Model):
	user = models.ForeignKey(User)
	orig_filename = models.CharField(max_length=100)
	full_filename = models.CharField(max_length=100, null=True)
	thumb_filename = models.CharField(max_length=100, null=True)
	hashcode = models.CharField(max_length=100, null=True)
	metadata = models.CharField(max_length=10000, null=True)
	location_data = models.TextField(null=True)
	location_city =  models.CharField(max_length=1000, null=True)
	twofishes_data = models.TextField(null=True)
	iphone_faceboxes_topleft = models.CharField(max_length=10000, null=True)
	classification_data = models.CharField(max_length=10000, null=True)
	time_taken = models.DateTimeField(null=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	"""
		Look to see from the iphone's location data if there's a city present
		TODO(derek):  Should this be pulled out to its own table?
	"""
	def getLocationCity(self, locationJson):
		if (locationJson):
			locationData = json.loads(locationJson)

			if ('address' in locationData):
				address = locationData['address']
				if ('City' in address):
					city = address['City']
					return city
		return None

	def save(self, *args, **kwargs):
		city = self.getLocationCity(self.location_data)
		if (city):
			self.location_city = city
		
		models.Model.save(self, *args, **kwargs)

	"""
		Returns back just the filename for the thumbnail.
		So if:  /home/blah/1/1234-thumb-156.jpg
		Will return:  1234-thumb-156.jpg

		This is used as a stopgap, the db also has this name
	"""
	def getThumbFilename(self):
		return str(self.id) + "-thumb-" + str(settings.THUMBNAIL_SIZE) + '.jpg'

	"""
		Returns back the full localfile path of the thumb
		So:  /home/blah/1/1234-thumb-156.jpg
	"""
	def getThumbPath(self):
		return os.path.join(self.user.getUserDataPath(), self.getThumbFilename())

	"""
		Returns back just the filename for the fullsize image.
		So if:  /home/blah/1/1234.jpg
		Will return:  1234.jpg

		This is used as a stopgap, the db also has this name
	"""
	def getFullFilename(self):
		baseWithoutExtension, fileExtension = os.path.splitext(self.orig_filename)
		fullFilename = str(self.id) + fileExtension

		return fullFilename

	"""
		Returns back the full localfile path of the thumb
		So:  /home/blah/1/1234.jpg
	"""
	def getFullPath(self):
		return os.path.join(self.user.getUserDataPath(), self.getFullFilename())

	def __unicode__(self):
		return u'%s/%s' % (self.user, self.full_filename)

class Classification(models.Model):
	photo = models.ForeignKey(Photo)
	user = models.ForeignKey(User)
	class_name = models.CharField(max_length=100)
	rating = models.FloatField()

	def __unicode__(self): 
		return str(self.photo.id) + " " + self.class_name

class Similarity(models.Model):
	photo_1 = models.ForeignKey(Photo, related_name="photo_1")
	photo_2 = models.ForeignKey(Photo, related_name="photo_2")
	similarity = models.IntegerField()
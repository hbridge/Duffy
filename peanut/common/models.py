import os
import json
import datetime

from django.contrib.gis.db import models

from peanut import settings

from common import bulk_updater

from ios_notifications.models import Notification


# Create your models here.
class User(models.Model):
	first_name = models.CharField(max_length=100, null=True)
	last_name = models.CharField(max_length=100, null=True)
	phone_id = models.CharField(max_length=100)
	product_id = models.IntegerField(default=0)
	device_token = models.TextField()
	last_location_point = models.PointField(null=True)
	last_location_timestamp = models.DateTimeField(null=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	class Meta:
		db_table = 'photos_user'
		unique_together = ("phone_id", "product_id")

	# You MUST use GeoManager to make Geo Queries
	objects = models.GeoManager()

	"""
		Returns back the full localfile path where the user's photos are located
		So:  /home/blah/1/
	"""
	def getUserDataPath(self):
		return os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, str(self.id))

	def __unicode__(self):
		if self.product_id == 0:
			productStr = "Arbus"
		else:
			productStr = "Strand"
			
		return "(%s - %s) %s - %s" % (self.id, productStr, self.first_name, self.phone_id)


class Photo(models.Model):
	user = models.ForeignKey(User)
	orig_filename = models.CharField(max_length=100, null=True)
	full_filename = models.CharField(max_length=100, null=True)
	thumb_filename = models.CharField(max_length=100, null=True)
	metadata = models.CharField(max_length=10000, null=True)
	location_data = models.TextField(null=True)
	location_city =  models.CharField(max_length=1000, null=True)
	location_point = models.PointField(null=True)
	twofishes_data = models.TextField(null=True)
	iphone_faceboxes_topleft = models.CharField(max_length=10000, null=True)
	iphone_hash = models.CharField(max_length=100, null=True)
	is_local = models.BooleanField(default=1)
	classification_data = models.CharField(max_length=10000, null=True)
	overfeat_data = models.TextField(null=True)
	faces_data = models.TextField(null=True)
	time_taken = models.DateTimeField(null=True)
	clustered_time = models.DateTimeField(null=True)
	neighbored_time = models.DateTimeField(null=True)
	file_key = models.CharField(max_length=100, null=True)
	bulk_batch_key = models.IntegerField(null=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	 # You MUST use GeoManager to make Geo Queries
	objects = models.GeoManager()

	class Meta:
		unique_together = ("user", "iphone_hash")
		db_table = 'photos_photo'

	def __unicode__(self):
		return str(self.id)

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
	def getDefaultThumbFilename(self):
		return str(self.id) + "-thumb-" + str(settings.THUMBNAIL_SIZE) + '.jpg'

	"""
		Returns back the full localfile path of the thumb
		If the file was moved though this could be different from the default
		So:  /home/blah/1/1234-thumb-156.jpg
	"""
	def getThumbPath(self):
		if self.thumb_filename:
			userPath = os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, str(self.user_id))
			return os.path.join(userPath, self.thumb_filename)
		else:
			return None

	"""
		Returns back the full localfile path of the thumb
		So:  /home/blah/1/1234-thumb-156.jpg
	"""
	def getDefaultThumbPath(self):
		return os.path.join(self.user.getUserDataPath(), self.getDefaultThumbFilename())

	"""
		Returns back just the filename for the fullsize image.
		So if:  /home/blah/1/1234.jpg
		Will return:  1234.jpg

		This is used as a stopgap, the db also has this name
	"""
	def getDefaultFullFilename(self):
		baseWithoutExtension, fileExtension = os.path.splitext(self.orig_filename)
		fullFilename = str(self.id) + fileExtension

		return fullFilename

	"""
		Returns back the full localfile path of the full res image
		If the file was moved though this could be different from the default
		So:  /home/blah/1/1234.jpg
	"""
	def getFullPath(self):
		if self.full_filename:
			return os.path.join(self.user.getUserDataPath(), self.full_filename)
		else:
			return None

	"""
		Returns back the default path for a new full res image
		So:  /home/blah/1/1234.jpg
	"""
	def getDefaultFullPath(self):
		return os.path.join(self.user.getUserDataPath(), self.getDefaultFullFilename())


	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		for obj in objs:
			obj.updated = datetime.datetime.now()

		attributesList.append("updated")

		bulk_updater.bulk_update(objs, update_fields=attributesList)

	@classmethod
	def getPhotosIds(cls, photos):
		ids = list()
		for photo in photos:
			ids.append(photo.id)

		return ids
	
	def __eq__(self, other):
		# Apparently django is sending different types of objects as 'other'.  Sometimes its an object
		# and sometimes its an id
		try:
			return self.id == other['id']
		except TypeError:
			return self.id == other.id

class SimplePhoto:
	id = None
	time_taken = None
	user_id = None
	first_name = None

	def serialize(self):
		return {key:value for key, value in self.__dict__.items() if not key.startswith('__') and not callable(key)}

	def __init__(self, solrOrDbPhoto):
		if hasattr(solrOrDbPhoto, 'photoId'):
			# This is a solr photo
			self.id = solrOrDbPhoto.photoId
			self.time_taken = solrOrDbPhoto.timeTaken
			self.user_id = solrOrDbPhoto.userId
		else:
			# This is a database photo
			self.id = solrOrDbPhoto.id
			self.time_taken = solrOrDbPhoto.time_taken
			self.user_id = solrOrDbPhoto.user_id
			self.first_name = solrOrDbPhoto.user.first_name

class Classification(models.Model):
	photo = models.ForeignKey(Photo)
	user = models.ForeignKey(User)
	class_name = models.CharField(max_length=100)
	rating = models.FloatField()

	class Meta:
		db_table = 'photos_classification'

	def __unicode__(self): 
		return str(self.photo.id) + " " + self.class_name

class Similarity(models.Model):
	photo_1 = models.ForeignKey(Photo, related_name="photo_1")
	photo_2 = models.ForeignKey(Photo, related_name="photo_2")
	user = models.ForeignKey(User)
	similarity = models.IntegerField()

	class Meta:
		unique_together = ("photo_1", "photo_2")
		db_table = 'photos_similarity'

	def __unicode__(self):
		return '{0}, {1}, {2}'.format(self.photo_1.id, self.photo_2.id, self.similarity)


class Neighbor(models.Model):
	user_1 = models.ForeignKey(User, related_name="neighbor_user_1")
	user_2 = models.ForeignKey(User, related_name="neighbor_user_2")
	photo_1 = models.ForeignKey(Photo, related_name="neighbor_photo_1")
	photo_2 = models.ForeignKey(Photo, related_name="neighbor_photo_2")
	time_distance_sec = models.IntegerField()
	geo_distance_m = models.IntegerField()
	added = models.DateTimeField(auto_now_add=True)

	class Meta:
		unique_together = ("photo_1", "photo_2")
		db_table = 'strand_neighbor'

	def __unicode__(self):
		return '{0}, {1}, {2}, {3}'.format(self.photo_1.id, self.photo_2.id, self.time_distance_sec, self.geo_distance_m)

class NotificationLog(models.Model):
	user = models.ForeignKey(User)
	device_token = models.TextField()
	msg = models.TextField()
	apns = models.IntegerField()
	added = models.DateTimeField(auto_now_add=True)

	class Meta:
		db_table = 'strand_notification_log'


	def __unicode__(self):
		return '{0}, {1}, {2}, {3}, {4}'.format(self.user_id, self.notification_id, device_token, apns)


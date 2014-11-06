import os
import json
import datetime
import logging

from django.contrib.gis.db import models
from django.template.defaultfilters import escape
from django.db.models import Q
from django.core.urlresolvers import reverse
from django.db.models.signals import pre_delete, post_save
from django.dispatch import receiver

from phonenumber_field.modelfields import PhoneNumberField
from uuidfield import UUIDField

from peanut.settings import constants

from common import bulk_updater

from ios_notifications.models import Notification

logger = logging.getLogger(__name__)

# Create your models here.
class User(models.Model):
	uuid = UUIDField(auto=True)
	display_name = models.CharField(max_length=100)
	phone_id = models.CharField(max_length=100, null=True)
	phone_number = PhoneNumberField(null=True, db_index=True)
	auth_token = models.CharField(max_length=100, null=True)
	product_id = models.IntegerField(default=0)
	device_token = models.TextField(null=True)
	last_location_point = models.PointField(null=True)
	last_location_accuracy = models.IntegerField(null=True)
	last_location_timestamp = models.DateTimeField(null=True)
	last_photo_timestamp = models.DateTimeField(null=True)
	last_photo_update_timestamp = models.DateTimeField(null=True)
	first_run_sync_timestamp = models.DateTimeField(null=True)
	first_run_sync_count = models.IntegerField(null=True)
	first_run_sync_complete = models.BooleanField(default=False)
	invites_remaining = models.IntegerField(default=5)
	invites_sent = models.IntegerField(default=0)
	api_cache_private_strands_dirty = models.BooleanField(default=True)
	last_build_info = models.CharField(max_length=100, null=True)
	install_num = models.IntegerField(default=0)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	class Meta:
		db_table = 'photos_user'
		unique_together = (("phone_id", "product_id"), ("phone_number", "product_id"))

	# You MUST use GeoManager to make Geo Queries
	objects = models.GeoManager()

	"""
		Returns back the full localfile path where the user's photos are located
		So:  /home/blah/1/
	"""
	def getUserDataPath(self):
		return os.path.join(constants.PIPELINE_LOCAL_BASE_PATH, self.getUserDataId())

	def getUserDataId(self):
		return str(self.uuid)

	def photos_info(self):
		photoCount = self.photo_set.count()

		if photoCount == 1:
			return "1 photo"
		else:
			return "%s photos" % (photoCount)

	def private_strands(self):
		strands = self.strand_set.filter(private=True)

		photoCount = 0
		for strand in strands:
			photoCount += strand.photos.count()

		if len(strands) == 1:
			return "1 strand"
		else:
			return "%s strands (%s photos)" % (len(strands), photoCount)

	def shared_strands(self):
		strandCount = self.strand_set.filter(private=False).count()

		if strandCount == 1:
			return "1 strand"
		else:
			return "%s strands" % (strandCount)

	def missingPhotos(self):
		strands = self.strand_set.filter(private=True)

		photosInStrands = list()
		[photosInStrands.extend(strand.photos.all()) for strand in strands]

		links = list()
		for photo in self.photo_set.all():
			if photo not in photosInStrands:
				links.append('<a href="%s">%s</a>' % (reverse("admin:common_photo_change", args=(photo.id,)) , escape(photo)))

		return ', '.join(links)
	missingPhotos.allow_tags = True
	missingPhotos.short_description = "Missing photos"

	@classmethod
	def getIds(cls, objs):
		ids = list()
		for obj in objs:
			ids.append(obj.id)

		return ids

	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		if not isinstance(objs, list):
			objs = [objs]

		if not isinstance(attributesList, list):
			attributesList = [attributesList]
			
		for obj in objs:
			obj.updated = datetime.datetime.now()

		attributesList.append("updated")

		bulk_updater.bulk_update(objs, update_fields=attributesList)

	def __unicode__(self):
		if self.product_id == 0:
			productStr = "Arbus"
		else:
			productStr = "Strand"

		if self.phone_number:
			return "(%s - %s) %s - %s" % (self.id, productStr, self.display_name, self.phone_number)
		else:
			return "(%s - %s) %s - %s" % (self.id, productStr, self.display_name, self.phone_id)			

@receiver(pre_delete, sender=User, dispatch_uid='user_delete_signal')
def delete_empty_strands(sender, instance, using, **kwargs):
	user = instance
	strands = user.strand_set.all()
	for strand in strands:
		logger.debug("Deleting empty strand %s" % (strand.id))
		if strand.users.count() == 1 and strand.users.all()[0].id == user.id:
			strand.delete()

class Photo(models.Model):
	uuid = UUIDField(auto=True)
	user = models.ForeignKey(User)
	orig_filename = models.CharField(max_length=100, null=True)
	full_filename = models.CharField(max_length=100, null=True)
	thumb_filename = models.CharField(max_length=100, null=True, db_index=True)
	metadata = models.CharField(max_length=10000, null=True)
	full_width = models.IntegerField(null=True)
	full_height = models.IntegerField(null=True)
	location_data = models.TextField(null=True)
	location_city =  models.CharField(max_length=1000, null=True)
	location_point = models.PointField(null=True, db_index=True)
	location_accuracy_meters = models.IntegerField(null=True)
	twofishes_data = models.TextField(null=True)
	iphone_faceboxes_topleft = models.TextField(null=True)
	iphone_hash = models.CharField(max_length=100, null=True)
	is_local = models.BooleanField(default=1)
	classification_data = models.TextField(null=True)
	overfeat_data = models.TextField(null=True)
	faces_data = models.TextField(null=True)
	time_taken = models.DateTimeField(null=True, db_index=True)
	local_time_taken = models.DateTimeField(null=True)
	clustered_time = models.DateTimeField(null=True)
	neighbored_time = models.DateTimeField(null=True)
	strand_evaluated = models.BooleanField(default=False, db_index=True)
	strand_needs_reeval = models.BooleanField(default=False, db_index=True)
	taken_with_strand = models.BooleanField(default=True)
	file_key = models.CharField(max_length=100, null=True)
	bulk_batch_key = models.IntegerField(null=True, db_index=True)
	product_id = models.IntegerField(default=2, null=True, db_index=True)
	install_num = models.IntegerField(default=0)
	added = models.DateTimeField(auto_now_add=True, db_index=True)
	updated = models.DateTimeField(auto_now=True, db_index=True)

	 # You MUST use GeoManager to make Geo Queries
	objects = models.GeoManager()

	class Meta:
		db_table = 'photos_photo'
		index_together = ('iphone_hash', 'user')

	def __unicode__(self):
		return str(self.id)

	def getUserDataId(self):
		return str(self.uuid)
			
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
		return self.getUserDataId() + "-thumb-" + str(constants.THUMBNAIL_SIZE) + '.jpg'

	"""
		Returns back the full localfile path of the thumb
		If the file was moved though this could be different from the default
		So:  /home/blah/1/1234-thumb-156.jpg
	"""
	def getThumbPath(self):
		if self.thumb_filename:
			return os.path.join(self.user.getUserDataPath(), self.thumb_filename)
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
		fullFilename = self.getUserDataId() + fileExtension

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


	"""
		Returns the URL path (after the port) of the image.  Hardcoded for now but maybe change later
	"""
	def getFullUrlImagePath(self):
		if self.full_filename:
			return "/user_data/%s/%s" % (self.user.getUserDataId(), self.full_filename) 
		else:
			return ""

	"""
		Returns the URL path (after the port) of the image.  Hardcoded for now but maybe change later
	"""
	def getThumbUrlImagePath(self):
		if self.thumb_filename:
			return "/user_data/%s/%s" % (self.user.getUserDataId(), self.thumb_filename) 
		else:
			return ""

	def photoHtml(self):
		if self.thumb_filename:
			return "<img src='%s'></img>" % (self.getThumbUrlImagePath())
		if self.full_filename:
			return "<img src='%s'></img>" % (self.getFullUrlImagePath())
		else:
			return "No image"
	photoHtml.allow_tags = True
	photoHtml.short_description = "Photo"

	def strandListHtml(self):
		links = list()
		for strand in self.strand_set.all():
			links.append('<a href="%s">%s</a>' % (reverse("admin:common_strand_change", args=(strand.id,)) , escape(strand)))
		return ', '.join(links)	

	strandListHtml.allow_tags = True
	strandListHtml.short_description = "Strands"


	def private_strands(self):
		strandCount = self.strand_set.filter(private=True).count()

		return "%s" % (strandCount)

	def shared_strands(self):
		strandCount = self.strand_set.filter(private=False).count()

		return "%s" % (strandCount)

	"""
		Returns the URL path (after the port) of the image.  Hardcoded for now but maybe change later
	"""
	def getThumbUrlImagePath(self):
		if self.thumb_filename:
			return "/user_data/%s/%s" % (self.user.getUserDataId(), self.thumb_filename)
		else:
			return ""

	def getUserDisplayName(self):
		return self.user.display_name

	def delete(self):
		strands = self.strand_set.all()
		for strand in strands:
			if strand.photos.count() == 1 and strand.photos.all()[0].id == self.id:
				strand.delete()
				
		super(Photo, self).delete()
		
	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		if not isinstance(objs, list):
			objs = [objs]

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

	@classmethod
	def getIds(cls, objs):
		return [obj.id for obj in objs]
	
	def __eq__(self, other):
		# Apparently django is sending different types of objects as 'other'.  Sometimes its an object
		# and sometimes its an id
		try:
			return self.id == other['id']
		except TypeError:
			return self.id == other.id


"""
	Originally created to deal with SolrPhotos and DB photos which were different
	Might want to move soon though, not gaining a lot
"""
class SimplePhoto:
	id = None
	time_taken = None
	user = None
	display_name = None

	solrPhoto = None
	dbPhoto = None

	def serialize(self):
		return {'id' : self.id,
				'time_taken' : self.time_taken,
				'user' : self.user}
		
	def isDbPhoto(self):
		if self.dbPhoto:
			return True

	def getDbPhoto(self):
		return self.dbPhoto

	def __init__(self, solrOrDbPhoto):
		if hasattr(solrOrDbPhoto, 'photoId'):
			# This is a solr photo
			self.solrPhoto = solrOrDbPhoto

			self.id = self.solrPhoto.photoId
			self.time_taken = self.solrPhoto.timeTaken
			self.user = self.solrPhoto.userId
		else:
			# This is a database photo
			self.dbPhoto = solrOrDbPhoto

			self.id = self.dbPhoto.id
			self.time_taken = self.dbPhoto.time_taken
			self.user = self.dbPhoto.user_id
			#self.display_name = self.dbPhoto.user.display_name

			

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

class NotificationLog(models.Model):
	user = models.ForeignKey(User)
	device_token = models.TextField(null=True)
	msg = models.TextField(null=True)
	msg_type = models.IntegerField(db_index=True)
	custom_payload = models.TextField(null=True)
	metadata = models.TextField(null=True)
	# Not used, probably can remove at some point
	apns = models.IntegerField(null=True)
	result = models.IntegerField(db_index=True, null=True)
	added = models.DateTimeField(auto_now_add=True, db_index=True)
	updated = models.DateTimeField(auto_now=True, db_index=True)
	

	class Meta:
		db_table = 'strand_notification_log'


	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		now = datetime.datetime.utcnow()
		for obj in objs:
			obj.updated = now

		attributesList.append("updated")

		bulk_updater.bulk_update(objs, update_fields=attributesList)
		
	def __unicode__(self):
		return "%s %s %s %s" % (self.user_id, self.id, self.device_token, self.apns)

class SmsAuth(models.Model):
	phone_number =  models.CharField(max_length=50, db_index=True)
	access_code = models.IntegerField()
	user_created = models.ForeignKey(User, null=True)
	added = models.DateTimeField(auto_now_add=True)

	class Meta:
		db_table = 'strand_sms_auth'

	def __unicode__(self):
		return "%s %s %s" % (self.id, self.phone_number, self.added)

class DuffyNotification(Notification):
	content_available = models.IntegerField(null=True)

	"""
		Override from main ios_notifications library
	"""
	@property
	def payload(self):
		aps = {}
		if self.message:
			aps['alert'] = self.message
		else:
			aps['alert'] = ''

		if self.badge is not None:
			aps['badge'] = self.badge

		if self.sound:
			aps['sound'] = self.sound
				
		if self.content_available:
			aps['content-available'] = self.content_available
			
		message = {'aps': aps}
		extra = self.extra
		if extra is not None:
			message.update(extra)
		payload = json.dumps(message, separators=(',', ':'))
		return payload

class ContactEntry(models.Model):
	user = models.ForeignKey(User, db_index=True)
	name = models.CharField(max_length=100)
	phone_number = models.CharField(max_length=128, db_index=True)
	evaluated = models.BooleanField(db_index=True, default=False)
	skip = models.BooleanField(db_index=True, default=False)
	contact_type = models.CharField(max_length=30, null=True)
	bulk_batch_key = models.IntegerField(null=True, db_index=True)
	added = models.DateTimeField(auto_now_add=True, db_index=True)
	updated = models.DateTimeField(auto_now=True)

	class Meta:
		db_table = 'strand_contacts'

	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		for obj in objs:
			obj.updated = datetime.datetime.now()

		if isinstance(attributesList, list):
			attributesList.append("updated")
		else:
			attributesList = [attributesList, "updated"]

		bulk_updater.bulk_update(objs, update_fields=attributesList)

class FriendConnection(models.Model):
	user_1 = models.ForeignKey(User, related_name="friend_user_1", db_index=True)
	user_2 = models.ForeignKey(User, related_name="friend_user_2", db_index=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	class Meta:
		unique_together = ("user_1", "user_2")
		db_table = 'strand_friends'

	@classmethod
	def friendConnectionExists(cls, user1, user2, existingFriendConnections):
		for connection in existingFriendConnections:
			if connection.user_1.id == user1.id and connection.user_2.id == user2.id:
				return True

	@classmethod
	def addNewConnections(cls, userToAddTo, users):
		allUsers = list()
		allUsers.extend(users)
		allUsers.append(userToAddTo)
		
		existingFriendConnections = FriendConnection.objects.filter(Q(user_1__in=allUsers) | Q(user_2__in=allUsers))
		newFriendConnections = list()
		for user in users:
			if user.id == userToAddTo.id:
				continue
			if (user.id < userToAddTo.id and not cls.friendConnectionExists(user, userToAddTo, existingFriendConnections)):
				newFriendConnections.append(FriendConnection(user_1 = user, user_2 = userToAddTo))
			elif (userToAddTo.id < user.id and not cls.friendConnectionExists(userToAddTo, user, existingFriendConnections)):
				newFriendConnections.append(FriendConnection(user_1 = userToAddTo, user_2 = user))

		FriendConnection.objects.bulk_create(newFriendConnections)

class Strand(models.Model):
	first_photo_time = models.DateTimeField(db_index=True)
	last_photo_time = models.DateTimeField(db_index=True)
	
	# These should come from the first photo
	location_city =  models.CharField(max_length=1000, null=True)
	location_point = models.PointField(null=True, db_index=True)
	
	photos = models.ManyToManyField(Photo)
	users = models.ManyToManyField(User)
	private = models.BooleanField(db_index=True, default=False)
	user = models.ForeignKey(User, null=True, related_name="owner", db_index=True)
	product_id = models.IntegerField(default=2, db_index=True)

	# This is the id of the private Strand that created this.  Not doing ForeignKey because
	#   django isn't good with recusive
	created_from_id = models.IntegerField(null=True)

	# This is the id of the public strand that this private strand swapped photos with
	contributed_to_id = models.IntegerField(null=True)

	suggestible = models.BooleanField(default=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)	

	def __unicode__(self):
		return str(self.id)
		
	def user_info(self):
		names = [str(user) for user in self.users.all()]
		return " & ".join(names)

	def photo_info(self):
		photoCount = self.photos.count()

		if photoCount == 1:
			return "1 photo"
		else:
			return "%s photos" % (photoCount)

	def photo_posts_info(self):
		postActions = self.action_set.filter(Q(action_type=constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND) | Q(action_type=constants.ACTION_TYPE_CREATE_STRAND))
		return "%s posts" % len(postActions)
		
	def sharing_info(self):
		if self.private:
			return "Private"
		else:
			return "Shared"

	def photos_link(self):
		photos = self.photos.all()

		links = list()
		for photo in photos:
			links.append('<a href="%s">%s</a>' % (reverse("admin:common_photo_change", args=(photo.id,)) , escape(photo)))
		return ', '.join(links)		
	photos_link.allow_tags = True
	photos_link.short_description = "Photos"

	def users_link(self):
		users = self.users.all()

		links = list()
		for user in users:
			links.append('<a href="%s">%s</a>' % (reverse("admin:common_user_change", args=(user.id,)) , escape(user)))
		return ', '.join(links)

	users_link.allow_tags = True
	users_link.short_description = "Users"
	
	def getPostPhotos(self):
		postActions = self.action_set.filter(action_type=constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND)
		photos = list()
		for action in postActions:
			photos.extend(action.photos.all())

		return sorted(photos, key=lambda x: x.time_taken, reverse=True)


	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		for obj in objs:
			obj.updated = datetime.datetime.now()

		if isinstance(attributesList, list):
			attributesList.append("updated")
		else:
			attributesList = [attributesList, "updated"]

		bulk_updater.bulk_update(objs, update_fields=attributesList)
		
	@classmethod
	def getIds(cls, objs):
		ids = list()
		for obj in objs:
			ids.append(obj.id)

		return ids

	class Meta:
		db_table = 'strand_objects'

	# You MUST use GeoManager to make Geo Queries
	objects = models.GeoManager()
		
class StrandInvite(models.Model):
	strand = models.ForeignKey(Strand, db_index=True)
	user = models.ForeignKey(User, db_index=True, related_name="inviting_user")
	phone_number = models.CharField(max_length=128, db_index=True) 
	invited_user = models.ForeignKey(User, null=True, db_index=True, related_name="invited_user")
	accepted_user = models.ForeignKey(User, null=True, db_index=True, related_name="accepted_user", blank=True)
	bulk_batch_key = models.IntegerField(null=True, db_index=True)
	skip = models.BooleanField(default=False, db_index=True)
	notification_sent = models.DateTimeField(null=True, blank=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)	

	class Meta:
		db_table = 'strand_invite'
		unique_together = ("strand", "user", "phone_number")

	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		for obj in objs:
			obj.updated = datetime.datetime.now()

		if isinstance(attributesList, list):
			attributesList.append("updated")
		else:
			attributesList = [attributesList, "updated"]

		bulk_updater.bulk_update(objs, update_fields=attributesList)


class StrandNeighbor(models.Model):
	strand_1 = models.ForeignKey(Strand, db_index=True, related_name = "strand_1")
	strand_1_private = models.BooleanField(db_index=True, default=False)
	strand_1_user = models.ForeignKey(User, db_index=True, null=True, related_name = "strand_1_user")

	strand_2 = models.ForeignKey(Strand, db_index=True, related_name = "strand_2")
	strand_2_private = models.BooleanField(db_index=True, default=False)
	strand_2_user = models.ForeignKey(User, db_index=True, null=True, related_name = "strand_2_user")

	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)	

	def __unicode__(self):
		return str(self.id)
		
	class Meta:
		unique_together = ("strand_1", "strand_2")
		db_table = 'strand_neighbor'

	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		for obj in objs:
			obj.updated = datetime.datetime.now()

		if isinstance(attributesList, list):
			attributesList.append("updated")
		else:
			attributesList = [attributesList, "updated"]

		bulk_updater.bulk_update(objs, update_fields=attributesList)


class Action(models.Model):
	user = models.ForeignKey(User, db_index=True)
	action_type = models.IntegerField(db_index=True)
	photo = models.ForeignKey(Photo, db_index=True, related_name = "action_photo", null=True)
	photos = models.ManyToManyField(Photo, related_name = "action_photos")
	strand = models.ForeignKey(Strand, db_index=True, null=True)
	notification_sent = models.DateTimeField(null=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	def getUserDisplayName(self):
		return self.user.display_name
	
	def __unicode__(self):
		return "%s %s %s %s" % (self.user.id, self.action_type, self.strand, self.added)

	class Meta:
		db_table = 'strand_action'

	@classmethod
	def bulkUpdate(cls, objs, attributesList):
		for obj in objs:
			obj.updated = datetime.datetime.now()

		if isinstance(attributesList, list):
			attributesList.append("updated")
		else:
			attributesList = [attributesList, "updated"]

		bulk_updater.bulk_update(objs, update_fields=attributesList)


class ApiCache(models.Model):
	user = models.ForeignKey(User, db_index=True, unique=True)
	private_strands_data = models.TextField(null=True)

	class Meta:
		db_table = 'strand_api_cache'


class LocationRecord(models.Model):
	user = models.ForeignKey(User, db_index=True)
	point = models.PointField(db_index=True)
	accuracy = models.IntegerField(null=True)
	timestamp = models.DateTimeField(null=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	class Meta:
		db_table = 'strand_location_records'


@receiver(post_save, sender=Action)
def sendNotificationsUponActions(sender, **kwargs):
	action = kwargs.get('instance')

	users = list()

	if action.strand:
		users = list(action.strand.users.all())
		
	if action.user and action.user not in users:
		users.append(action.user)

	# First send to sockets
	for user in users:
		logger.debug("Sending refresh feed to user %s from action_save" % (user.id))
		logEntry = NotificationLog.objects.create(user=user, msg_type=constants.NOTIFICATIONS_SOCKET_REFRESH_FEED)



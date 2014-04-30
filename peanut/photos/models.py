from django.db import models

# Create your models here.
class User(models.Model):
	first_name = models.CharField(max_length=100, null=True)
	last_name = models.CharField(max_length=100, null=True)
	phone_id = models.CharField(max_length=100)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	def __unicode__(self):
		return self.first_name + " " + self.last_name + " - " + self.phone_id

class Photo(models.Model):
	user = models.ForeignKey(User)
	orig_filename = models.CharField(max_length=100)
	new_filename = models.CharField(max_length=100, blank=True, default="")
	upload_date = models.DateTimeField()
	hashcode = models.CharField(max_length=100, null=True)
	metadata = models.CharField(max_length=10000, null=True)
	location_data = models.TextField(null=True)
	location_city =  models.CharField(max_length=1000, null=True)
	twofishes_data = models.TextField(null=True)
	pipeline_state = models.IntegerField(default=0)
	iphone_faceboxes_topleft = models.CharField(max_length=10000, null=True)
	classification_data = models.CharField(max_length=10000, null=True, default="")
	time_taken = models.DateTimeField(null=True)
	added = models.DateTimeField(auto_now_add=True)
	updated = models.DateTimeField(auto_now=True)

	def __unicode__(self):
		return u'%s/%s' % (self.user, self.new_filename)

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
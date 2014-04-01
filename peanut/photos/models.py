from django.db import models

# Create your models here.
class User(models.Model):
	first_name = models.CharField(max_length=100, null=True)
	last_name = models.CharField(max_length=100, null=True)
	phone_id = models.CharField(max_length=100)

	def __unicode__(self):
		return self.first_name + " " + self.last_name + " - " + self.phone_id

class Photo(models.Model):
	user = models.ForeignKey(User)
	orig_filename = models.CharField(max_length=100)
	new_filename = models.CharField(max_length=100, blank=True, default="")
	upload_date = models.DateTimeField()
	hashcode = models.CharField(max_length=100, null=True)
	metadata = models.CharField(max_length=10000, null=True)
	location_data = models.CharField(max_length=10000, null=True)
	pipeline_state = models.IntegerField(default=0)
	iphone_faceboxes_topleft = models.CharField(max_length=10000, null=True)
	classification_data = models.CharField(max_length=10000, null=True)

	def __unicode__(self): 
		return str(self.user) + "/" + str(self.new_filename)

class Classification(models.Model):
	photo = models.ForeignKey(Photo)
	user = models.ForeignKey(User)
	class_name = models.CharField(max_length=100)
	rating = models.FloatField()

	def __unicode__(self): 
		return str(self.photo.id) + " " + self.class_name
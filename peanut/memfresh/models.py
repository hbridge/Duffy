from django.db import models
from django.contrib import admin

from oauth2client.django_orm import CredentialsField


class User(models.Model):
	phone_number = models.CharField(max_length=100, unique=True)
	name = models.CharField(max_length=100)
	email = models.CharField(max_length=100)
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

	def __unicode__(self):
		return str(self.id)

class CredentialsModel(models.Model):
	user = models.ForeignKey(User, primary_key=True)
	credential = CredentialsField()

	def __unicode__(self):
		return str(self.id)

class ContactEntry(models.Model):
	user = models.ForeignKey(User, db_index=True)
	name = models.CharField(max_length=100)
	phone_number = models.CharField(max_length=128, db_index=True)
	email = models.CharField(max_length=100)
	added = models.DateTimeField(auto_now_add=True, db_index=True)
	updated = models.DateTimeField(auto_now=True)

	class Meta:
		unique_together = ('user', 'email')

	def __unicode__(self):
		return str(self.id)
	
class FollowUp(models.Model):
	user = models.ForeignKey(User)
	contact = models.ForeignKey(ContactEntry)
	text = models.CharField(max_length=1000, null=True)
	sent_back = models.BooleanField(default=False)
	from_event_id = models.CharField(max_length=1000)
	added = models.DateTimeField(auto_now_add=True, db_index=True)
	updated = models.DateTimeField(auto_now=True, db_index=True)

	def __unicode__(self):
		return str(self.id)

admin.site.register(User)
admin.site.register(CredentialsModel)
admin.site.register(ContactEntry)
admin.site.register(FollowUp)
from django.db import models
from django.contrib import admin

class User(models.Model):
	phone_number = models.CharField(max_length=100, unique=True)
	name = models.CharField(max_length=100)
	
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

	def __unicode__(self):
		return str(self.id)

class Note(models.Model):
	user = models.ForeignKey(User, db_index=True)
	label = models.CharField(max_length=100)
	
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)


class NoteEntry(models.Model):
	note = models.ForeignKey(Note, db_index=True)
	text = models.TextField(null=True)
	img_urls_json = models.TextField(null=True)

	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

class IncomingMessage(models.Model):
	user = models.ForeignKey(User, db_index=True)
	msg_json = models.TextField(null=True)

	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

admin.site.register(User)
admin.site.register(Note)
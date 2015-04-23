from django.db import models


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
	text = models.TextField(null=True)
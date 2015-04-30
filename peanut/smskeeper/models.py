from django.db import models
from django.contrib import admin
import json
from django.utils.html import format_html
from common import api_util

class User(models.Model):
	phone_number = models.CharField(max_length=100, unique=True)
	name = models.CharField(max_length=100)
	completed_tutorial = models.BooleanField(default=False)
	tutorial_step = models.IntegerField(default=0)
	activated = models.BooleanField(default=False)
	
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)


	def history(self):
		return format_html("<a href='/smskeeper/history?user_id=%s'>History</a>" % self.id)
		
	def last_msg_from(self):
		lastMsg = Message.objects.filter(user=self, incoming=True).order_by("-added")[:1]

		if len(lastMsg) > 0:
			return format_html("%s" % api_util.prettyDate(lastMsg[0].added))
		else:
			return format_html("None")

	def total_msgs_from(self):
		messages = Message.objects.filter(user=self, incoming=True)

		if len(messages) > 0:
			return format_html("%s" % len(messages))
		else:
			return format_html("None")

	def __unicode__(self):
		return str(self.id) + " - " + self.phone_number


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
	list_display = ('id', 'phone_number', 'name', 'completed_tutorial', 'tutorial_step', 'last_msg_from', 'total_msgs_from', 'history')

class Note(models.Model):
	user = models.ForeignKey(User, db_index=True)
	label = models.CharField(max_length=100)
	
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)


class NoteEntry(models.Model):
	note = models.ForeignKey(Note, db_index=True)
	text = models.TextField(null=True)
	img_url = models.TextField(null=True)

	remind_timestamp = models.DateTimeField(null=True)
	
	hidden = models.BooleanField(default=False)

	keeper_number = models.CharField(max_length=100, null=True)

	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

class Message(models.Model):
	user = models.ForeignKey(User, db_index=True)
	msg_json = models.TextField(null=True)
	incoming = models.BooleanField(default=None)

	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)
	
	# calculated attributes
	messageDict = None
	def getMessageAttribute(self, attribute):
		if self.messageDict is None:
			self.messageDict = json.loads(self.msg_json)
		return self.messageDict.get(attribute, None)
	
	def getBody(self):
		return self.getMessageAttribute("Body")
		
	def getMedia(self):
		media = []
		mediaUrls = self.getMessageAttribute("MediaUrls")
		if mediaUrls:
			media.append(MessageMedia(mediaUrls, None))
			
		if not self.getMessageAttribute("NumMedia"):
			return media
		for n in range(int(self.getMessageAttribute("NumMedia"))):
			urlParam = 'MediaUrl' + str(n)
			typeParam = 'MediaContentType' + str(n)
			
			media.append(MessageMedia(self.getMessageAttribute(urlParam), self.getMessageAttribute(typeParam)))
			
		return media
		
class MessageMedia:
	url = None
	mediaType = None
	
	def __init__(self, url, mediaType):
		self.url = url
		self.mediaType = mediaType

admin.site.register(Note)
admin.site.register(NoteEntry)
admin.site.register(Message)
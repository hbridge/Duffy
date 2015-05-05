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
	activated = models.DateTimeField(null=True)

	timezone = models.CharField(max_length=100, null=True)

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
	list_display = ('id', 'activated', 'phone_number', 'name', 'completed_tutorial', 'tutorial_step', 'last_msg_from', 'total_msgs_from', 'history')

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

class Entry(models.Model):
	creator = models.ForeignKey(User)
	text = models.TextField(null=True)
	img_url = models.TextField(null=True)

	remind_timestamp = models.DateTimeField(null=True)

	hidden = models.BooleanField(default=False)

	keeper_number = models.CharField(max_length=100, null=True)

	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

	@classmethod
	def fetchAllLabels(cls, user):
		try:
			entryLinks = EntryLink.objects.filter(users__in=[user.id], entry__hidden=False)
			labels = entryLinks.values_list("label", flat=True).distinct()
			return labels
		except EntryLink.DoesNotExist:
			return []

	@classmethod
	def fetchFirstLabel(cls, user):
		try:
			entryLinks = EntryLink.objects.filter(users__in=[user.id], entry__hidden=False).order_by("added")
			return entryLinks[0].label
		except EntryLink.DoesNotExist:
			return None
		
	@classmethod
	def fetchEntries(cls, user, label=None, hidden=False):
		try:
			links = EntryLink.objects.filter(users=user, label=label, entry__hidden=hidden).order_by("added")
			return map(lambda link: link.entry, links)
		except EntryLink.DoesNotExist:
			return []

	@classmethod
	def createEntry(cls, user, keeper_number, label, text, img_url=None, remind_timestamp=None):
		entry = Entry.objects.create(creator=user, keeper_number=keeper_number, text=text, img_url=img_url, remind_timestamp=remind_timestamp)
		entry.save()
		entryLink = EntryLink.objects.create(label=label, entry=entry)
		entryLink.users.add(user)
		entryLink.save()
		return entry, entryLink

class EntryLink(models.Model):
	users = models.ManyToManyField(User, db_index=True)
	label = models.CharField(max_length=100, db_index=True)
	entry = models.ForeignKey(Entry, db_index=True)

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

	def NumMedia(self):
		numMedia = self.getMessageAttribute("NumMedia")
		if not numMedia:
			return 0
		return int(numMedia)

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

class Contact(models.Model):
	user = models.ForeignKey(User, db_index=True)
	target = models.ForeignKey(User, db_index=True, related_name="contact_target")
	handle = models.CharField(max_length=30, db_index=True)

admin.site.register(Message)

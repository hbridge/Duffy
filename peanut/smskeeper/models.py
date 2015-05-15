import logging
import json
import datetime

import pytz

from django.db import models
from django.utils.html import format_html

from common import api_util
from smskeeper import keeper_constants

logger = logging.getLogger(__name__)


class User(models.Model):
	phone_number = models.CharField(max_length=100, unique=True)
	name = models.CharField(max_length=100)
	completed_tutorial = models.BooleanField(default=False)
	tutorial_step = models.IntegerField(default=0)

	# TODO(Derek): Rename this to activated_timestamp
	activated = models.DateTimeField(null=True)

	state = models.CharField(max_length=100, default=keeper_constants.STATE_NOT_ACTIVATED)
	state_data = models.TextField(null=True)

	# Used by states to say "goto this state, but come back to me afterwards"
	next_state = models.CharField(max_length=100, null=True)
	next_state_data = models.TextField(null=True)

	last_state_change = models.DateTimeField(null=True)

	signup_data_json = models.TextField(null=True)

	timezone = models.CharField(max_length=100, null=True)
	sent_tips = models.TextField(null=True, db_index=False)
	disable_tips = models.BooleanField(default=False)

	tip_frequency_days = models.IntegerField(default=3)
	last_tip_sent = models.DateTimeField(null=True)
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

	def history(self):
		return format_html("<a href='/smskeeper/history?user_id=%s'>History</a>" % self.id)

	def print_last_message_date(self, incoming=True):
		lastMsg = Message.objects.filter(user=self, incoming=incoming).order_by("-added")[:1]

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

	def nameOrPhone(self):
		if self.name is not None and len(self.name) > 0:
			return self.name
		return self.phone_number

	def setState(self, state, override=False):
		# next state means that we want to override the wishes of the current state and do something different
		# it should all be configured already
		if not override and self.next_state:
			self.state = self.next_state
			self.state_data = self.next_state_data
		else:
			# Normal flow, if there's no next state already defined
			self.state = state
			self.state_data = None

		self.next_state = None
		self.next_state_data = None

		self.last_state_change = datetime.datetime.now(pytz.utc)

	def setNextState(self, nextState):
		self.next_state = nextState

	def getStateData(self, key):
		if self.state_data:
			data = json.loads(self.state_data)
			if key in data:
				return data[key]

		return None

	def setStateData(self, key, value):
		if self.state_data:
			data = json.loads(self.state_data)
		else:
			data = dict()
		data[key] = value

		self.state_data = json.dumps(data)

	def setNextStateData(self, key, value):
		if self.next_state_data:
			data = json.loads(self.next_state_data)
		else:
			data = dict()
		data[key] = value

		self.next_state_data = json.dumps(data)

	def getTimezone(self):
		if self.timezone:
			tz = pytz.timezone(self.timezone)
		else:
			tz = pytz.timezone('US/Eastern')

		return tz

	def getMessages(self, incoming):
		return Message.objects.filter(user=self, incoming=incoming).order_by("added")

	def isActivated(self):
		return self.activated is not None

	# Used only by user_util
	# Meant to double check data
	def setActivated(self, activatedDate=datetime.datetime.now(pytz.utc), tutorialState=keeper_constants.STATE_TUTORIAL_REMIND):
		self.activated = activatedDate
		if activatedDate:
			if self.isTutorialComplete():
				self.setState(keeper_constants.STATE_NORMAL)
			else:
				self.setState(tutorialState)
		else:
			self.setState(keeper_constants.STATE_NOT_ACTIVATED)
		self.save()

	def isTutorialComplete(self):
		return self.completed_tutorial

	def setTutorialComplete(self, completeDate=datetime.datetime.now(pytz.utc)):
		if self.state == keeper_constants.STATE_NOT_ACTIVATED or not self.activated:
			raise NameError("Trying to set unactivated user to tutorial passed")

		if completeDate is not None:
			self.completed_tutorial = True
			self.setState(keeper_constants.STATE_NORMAL)
		else:
			self.completed_tutorial = False
			self.setState(keeper_constants.STATE_TUTORIAL_REMIND)
		self.save()

	def __unicode__(self):
		return str(self.id) + " - " + self.phone_number


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
	creator = models.ForeignKey(User, related_name="creator")

	# creator will be in this list
	users = models.ManyToManyField(User, db_index=True, related_name="users")

	label = models.CharField(max_length=100, db_index=True)

	text = models.TextField(null=True)
	img_url = models.TextField(null=True)

	remind_timestamp = models.DateTimeField(null=True)

	hidden = models.BooleanField(default=False)

	keeper_number = models.CharField(max_length=100, null=True)

	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

	@classmethod
	def fetchAllLabels(cls, user):
		entries = Entry.objects.filter(users__in=[user], hidden=False)
		labels = entries.values_list("label", flat=True).distinct()
		return labels

	@classmethod
	def fetchFirstLabel(cls, user):
		entries = Entry.objects.filter(users__in=[user], hidden=False).order_by("added")[:1]
		if len(entries) > 0:
			return entries[0].label
		else:
			return None

	@classmethod
	def fetchEntries(cls, user, label=None, hidden=False):
		entries = Entry.objects.filter(users__in=[user], hidden=hidden).order_by("added")
		if label:
			entries = entries.filter(label=label)
		return entries

	@classmethod
	def createEntry(cls, user, keeper_number, label, text, img_url=None, remind_timestamp=None):
		entry = Entry.objects.create(creator=user, label=label, keeper_number=keeper_number, text=text, img_url=img_url, remind_timestamp=remind_timestamp)
		entry.users.add(user)
		return entry


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

	def getSenderName(self):
		if not self.incoming:
			return "Keeper"
		else:
			return self.user.nameOrPhone()

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

	@classmethod
	def fetchByHandle(cls, user, handle):
		try:
			contact = Contact.objects.get(user=user, handle=handle)
			return contact
		except Contact.DoesNotExist:
			return None


class ZipData(models.Model):
	city = models.CharField(max_length=100)
	state = models.CharField(max_length=10)
	zip_code = models.CharField(max_length=10, db_index=True)
	area_code = models.CharField(max_length=10, db_index=True)
	timezone = models.CharField(max_length=10)

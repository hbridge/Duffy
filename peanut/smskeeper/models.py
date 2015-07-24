import logging
import json

import pytz

from django.db import models
from django.db.models import Q
from django.utils.html import format_html

from common import api_util, date_util
from smskeeper import keeper_constants

from django.conf import settings

logger = logging.getLogger(__name__)


class User(models.Model):
	phone_number = models.CharField(max_length=100, unique=True)
	name = models.CharField(max_length=100, blank=True)
	completed_tutorial = models.BooleanField(default=False)
	tutorial_step = models.IntegerField(default=0)

	product_id = models.IntegerField(default=0)

	# TODO(Derek): Rename this to activated_timestamp
	activated = models.DateTimeField(null=True, blank=True)
	paused = models.BooleanField(default=False)

	last_paused_timestamp = models.DateTimeField(null=True, blank=True)

	STATE_CHOICES = [(x, x) for x in keeper_constants.ALL_STATES]
	state = models.CharField(max_length=100, choices=STATE_CHOICES, default=keeper_constants.STATE_NOT_ACTIVATED)
	last_state = models.CharField(max_length=100, choices=STATE_CHOICES, default=keeper_constants.STATE_NOT_ACTIVATED)

	state_data = models.TextField(null=True, blank=True)

	# Used by states to say "goto this state, but come back to me afterwards"
	next_state = models.CharField(max_length=100, null=True, blank=True)
	next_state_data = models.TextField(null=True, blank=True)

	last_state_change = models.DateTimeField(null=True, blank=True)

	signup_data_json = models.TextField(null=True, blank=True)

	invite_code = models.CharField(max_length=100, null=True, blank=True)

	# Used as an identifier for a user instead of an id
	key = models.CharField(max_length=100, null=True, blank=True)

	timezone = models.CharField(max_length=100, null=True, blank=True)
	postal_code = models.CharField(max_length=10, null=True, blank=True)
	wxcode = models.CharField(max_length=10, null=True, blank=True)

	sent_tips = models.TextField(null=True, db_index=False, blank=True)
	disable_tips = models.BooleanField(default=False)

	digest_hour = models.IntegerField(default=9)
	digest_minute = models.IntegerField(default=0)

	tip_frequency_days = models.IntegerField(default=keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS)
	last_tip_sent = models.DateTimeField(null=True, blank=True)
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)
	last_share_upsell = models.DateTimeField(null=True, blank=True)
	last_feedback_prompt = models.DateTimeField(null=True, blank=True)

	overrideKeeperNumber = None

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

	def getFirstName(self):
		if self.name:
			return self.name.split(' ')[0]
		else:
			return None

	def setState(self, state, override=False, saveCurrent=False):
		if self.state == keeper_constants.STATE_STOPPED:
			logger.error("User %s: Tried to set state but was stopped" % (self.id))
			return

		logger.debug("User %s: Start of setState   %s %s" % (self.id, state, override))
		logger.debug("User %s: Starting state:  %s %s   and next state: %s %s" % (self.id, self.state, self.state_data, self.next_state, self.next_state_data))

		self.last_state = self.state
		self.last_state_change = date_util.now(pytz.utc)

		# next state means that we want to override the wishes of the current state and do something different
		# it should all be configured already
		if not override and self.next_state:
			self.state = self.next_state
		else:
			# Normal flow, if there's no next state already defined
			self.state = state

		if saveCurrent:
			self.next_state = self.last_state
		else:
			self.next_state = None

		logger.debug("User %s: End of setState.  new state:  %s %s  and next state: %s %s" % (self.id, self.state, self.state_data, self.next_state, self.next_state_data))

		self.save()

	def setNextState(self, nextState):
		self.next_state = nextState
		self.save()

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
		self.save()
		logger.debug("User %s: Setting state data %s %s" % (self.id, key, value))

	def getTimezone(self):
		# These mappings came from http://code.davidjanes.com/blog/2008/12/22/working-with-dates-times-and-timezones-in-python/
		# Note: 3 letter entries are to handle the early accounts. All new accounts use the full string
		if self.timezone and len(self.timezone) <= 5:
			if self.timezone == "PST":
				return pytz.timezone('US/Pacific')
			elif self.timezone == "EST":
				return pytz.timezone('US/Eastern')
			elif self.timezone == "CST":
				return pytz.timezone('US/Central')
			elif self.timezone == "MST":
				return pytz.timezone('US/Mountain')
			elif self.timezone == "PST-1":
				return pytz.timezone('US/Alaska')
			elif self.timezone == "PST-2":
				return pytz.timezone('US/Hawaii')
			elif self.timezone == "UTC":
				return pytz.utc
			else:
				logger.error("Didn't find %s tz for user %s, defaulting to Eastern but you should map this in models.py" % (self.timezone, self))
				return pytz.timezone('US/Eastern')
		# New accounts use the full string
		elif self.timezone and len(self.timezone) > 3:
			return pytz.timezone(self.timezone)
		else:
			return pytz.timezone('US/Eastern')

	def getMessages(self, incoming, ascending=True):
		orderByString = "added" if ascending else "-added"
		return Message.objects.filter(user=self, incoming=incoming).order_by(orderByString)

	def isActivated(self):
		return self.activated is not None

	# Used only by user_util
	# Meant to double check data
	def setActivated(self, isActivated, customActivatedDate=None, tutorialState=keeper_constants.STATE_TUTORIAL_REMIND):
		if isActivated:
			self.activated = customActivatedDate if customActivatedDate is not None else date_util.now(pytz.utc)
			if self.isTutorialComplete():
				self.setState(keeper_constants.STATE_NORMAL)
			else:
				self.setState(tutorialState)
		else:
			self.activated = None
			self.setState(keeper_constants.STATE_NOT_ACTIVATED)
		self.save()

	def isTutorialComplete(self):
		return self.completed_tutorial

	def setTutorialComplete(self):
		if self.state == keeper_constants.STATE_NOT_ACTIVATED or not self.activated:
			raise NameError("Trying to set unactivated user to tutorial passed")

		self.completed_tutorial = True
		self.save()

	def isPaused(self):
		return self.paused

	def getInviteUrl(self):
		url = "getkeeper.com"
		if self.invite_code:
			url += "/%s" % (self.invite_code)
		return url

	def getKeeperNumber(self):
		if self.overrideKeeperNumber:
			return self.overrideKeeperNumber

		if not settings.KEEPER_NUMBER_DICT:
			raise NameError("Keeper number dict not set")
		elif self.product_id not in settings.KEEPER_NUMBER_DICT:
			raise NameError(
				"Keeper number not set for product id %s, keeperNumberDict:%s"
				% (self.product_id, settings.KEEPER_NUMBER_DICT)
			)
		else:
			return settings.KEEPER_NUMBER_DICT[self.product_id]

	def getWebsiteURLPath(self):
		return "%s" % self.key

	def getWebAppURL(self):
		return "my.getkeeper.com/%s" % self.getWebsiteURLPath()

	def getSignupData(self, field):
		signupJson = self.signup_data_json
		if not signupJson or signupJson == "":
			return None
		signupObj = json.loads(signupJson)
		if type(signupObj) == unicode or type(signupObj) == str:
			return None
		return signupObj.get(field, None)

	# Returns true if the user should be sent the digest at the given utc time
	def isDigestTime(self, utcTime, minuteOverride=None):
		localTime = utcTime.astimezone(self.getTimezone())

		# By default only send if its 9 am
		# Later on might make this per-user specific
		if localTime.hour == self.getDigestHour():
			if minuteOverride:
				if localTime.minute == minuteOverride:
					return True
			elif localTime.minute == self.getDigestMinute():
				return True
		return False

	def getDigestHour(self):
		return self.digest_hour

	def getDigestMinute(self):
		return self.digest_minute

	def getLastEntries(self):
		if self.getStateData(keeper_constants.LAST_ENTRIES_IDS_KEY):
			entryIds = self.getStateData(keeper_constants.LAST_ENTRIES_IDS_KEY)
		elif self.getStateData(keeper_constants.ENTRY_IDS_DATA_KEY):
			entryIds = self.getStateData(keeper_constants.ENTRY_IDS_DATA_KEY)
		elif self.getStateData(keeper_constants.ENTRY_ID_DATA_KEY):
			entryIds = [self.getStateData(keeper_constants.ENTRY_ID_DATA_KEY)]
		else:
			return []

		entries = Entry.objects.filter(id__in=entryIds)
		return entries

	def __unicode__(self):
		if self.name:
			return str(self.id) + " - " + self.name
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
	users = models.ManyToManyField(User, db_index=True, related_name="users", null=True, blank=True)

	label = models.CharField(max_length=100, db_index=True, blank=True)

	text = models.TextField(null=True, blank=True)

	# Used by reminders.  Text from the user, without the timing words removed
	orig_text = models.TextField(null=True, blank=True)
	img_url = models.TextField(null=True, blank=True)

	remind_timestamp = models.DateTimeField(null=True, blank=True)
	remind_last_notified = models.DateTimeField(null=True, blank=True)
	remind_to_be_sent = models.BooleanField(default=True, db_index=True)
	is_default_time_and_date = models.BooleanField(default=False)

	RECURRENCE_CHOICES = [(x, x) for x in keeper_constants.RECURRENCE_CHOICES]
	remind_recur = models.CharField(max_length=100, choices=RECURRENCE_CHOICES, default=keeper_constants.RECUR_DEFAULT)
	remind_recur_end = models.DateTimeField(null=True, blank=True)

	hidden = models.BooleanField(default=False)

	manually_updated = models.BooleanField(default=False)
	manually_updated_timestamp = models.DateTimeField(null=True, blank=True)

	manually_check = models.BooleanField(default=False)
	manually_approved_timestamp = models.DateTimeField(null=True, blank=True)

	created_from_entry_id = models.IntegerField(null=True, blank=True)

	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

	@classmethod
	def fetchAllLabels(cls, user, hidden=False):
		if hidden is None:
			entries = Entry.objects.filter(Q(users__in=[user]) | Q(creator=user))
		else:
			entries = Entry.objects.filter(Q(users__in=[user]) | Q(creator=user)).filter(hidden=hidden)

		labels = entries.values_list("label", flat=True).distinct()
		return labels

	@classmethod
	def fetchFirstLabel(cls, user):
		entries = Entry.objects.filter(Q(users__in=[user]) | Q(creator=user)).filter(hidden=False).order_by("added")[:1]
		if len(entries) > 0:
			return entries[0].label
		else:
			return None

	@classmethod
	def fetchEntries(cls, user, label=None, hidden=False, orderByString="added"):
		entries = Entry.objects.filter(Q(users__in=[user]) | Q(creator=user)).order_by(orderByString)
		if hidden is not None:
			entries = entries.filter(hidden=hidden)
		if label:
			entries = entries.filter(label__iexact=label)
		return entries

	@classmethod
	def createEntry(cls, user, keeper_number, label, text, img_url=None, remind_timestamp=None):
		entry = Entry.objects.create(creator=user, label=label, text=text, img_url=img_url, remind_timestamp=remind_timestamp)
		entry.users.add(user)
		return entry


class Message(models.Model):
	user = models.ForeignKey(User, db_index=True)
	msg_json = models.TextField(null=True)
	incoming = models.BooleanField(default=None)
	manual = models.BooleanField(default=None)
	classification = models.CharField(max_length=100, db_index=True, null=True, blank=True)
	auto_classification = models.CharField(max_length=100, db_index=True, null=True, blank=True)

	classification_scores_json = models.CharField(max_length=1000, null=True, blank=True)
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)

	# calculated attributes
	messageDict = None

	def getBody(self):
		return self.getMessageAttribute("Body")

	@classmethod
	def getClassifiedAs(cls, classification):
		return Message.objects.filter(classification=classification)

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

	def getMessagePhoneNumbers(self):
		sender = None
		recipient = None
		msgInfo = json.loads(self.msg_json)
		sender = msgInfo.get("From", None)
		recipient = msgInfo.get("To", None)
		return sender, recipient

	@classmethod
	def Classifications(cls):
		return ([
			{
				"text": "Create Todo",
				"value": keeper_constants.CLASS_CREATE_TODO
			},
			{
				"text": "Done (most recent)",
				"value": keeper_constants.CLASS_COMPLETE_TODO_MOST_RECENT
			},
			{
				"text": "Done (specific)",
				"value": keeper_constants.CLASS_COMPLETE_TODO_SPECIFIC
			},
			{
				"text": "Delete/Cancel",
				"value": keeper_constants.CLASS_DELETE
			},
			{
				"text": "Fetch Digest",
				"value": keeper_constants.CLASS_FETCH_DIGEST
			},
			{
				"text": "Nicety",
				"value": keeper_constants.CLASS_NICETY
			},
			{
				"text": "Nicety (Silent)",
				"value": keeper_constants.CLASS_SILENT_NICETY
			},
			{
				"text": "Change time (most recent)",
				"value": keeper_constants.CLASS_CHANGETIME_MOST_RECENT
			},
			{
				"text": "Change time (specific)",
				"value": keeper_constants.CLASS_CHANGETIME_SPECIFIC
			},
			{
				"text": "Help",
				"value": keeper_constants.CLASS_HELP
			},
			{
				"text": "Stop",
				"value": keeper_constants.CLASS_STOP
			},
			{
				"text": "Get weather",
				"value": keeper_constants.CLASS_FETCH_WEATHER
			},
			{
				"text": "NoCategory",
				"value": keeper_constants.CLASS_NONE
			},

		])


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

	@classmethod
	def fetchByTarget(cls, user, target):
		try:
			contact = Contact.objects.get(user=user, target=target)
			return contact
		except Contact.DoesNotExist:
			return None


class ZipData(models.Model):
	city = models.CharField(max_length=100)
	state = models.CharField(max_length=100)
	country_code = models.CharField(max_length=10, null=True)
	postal_code = models.CharField(max_length=10, db_index=True)
	area_code = models.CharField(max_length=10, db_index=True)
	timezone = models.CharField(max_length=30)
	wxcode = models.CharField(max_length=10, null=True)


class VerbData(models.Model):
	base = models.CharField(max_length=40)
	past = models.CharField(max_length=40, db_index=True)
	past_participle = models.CharField(max_length=40, db_index=True)
	s_es_ies = models.CharField(max_length=40)
	ing = models.CharField(max_length=40)

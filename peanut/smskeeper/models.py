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
from simple_history.models import HistoricalRecords
from django.db.models import F


class User(models.Model):
	history = HistoricalRecords()
	phone_number = models.CharField(max_length=100, unique=True)
	name = models.CharField(max_length=100, blank=True)
	completed_tutorial = models.BooleanField(default=False)
	tutorial_step = models.IntegerField(default=0)

	product_id = models.IntegerField(default=0)
	zendesk_id = models.IntegerField(null=True, blank=True)

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
	signature_num_lines = models.IntegerField(null=True)

	stripe_data_json = models.TextField(null=True, blank=True)

	sent_tips = models.TextField(null=True, db_index=False, blank=True)
	disable_tips = models.BooleanField(default=False)

	digest_hour = models.IntegerField(default=9)
	digest_minute = models.IntegerField(default=0)

	DIGEST_CHOICES = [(x, x) for x in [keeper_constants.DIGEST_STATE_DEFAULT, keeper_constants.DIGEST_STATE_LIMITED, keeper_constants.DIGEST_STATE_NEVER]]
	digest_state = models.CharField(max_length=20, choices=DIGEST_CHOICES, default=keeper_constants.DIGEST_STATE_DEFAULT)

	tip_frequency_days = models.IntegerField(default=keeper_constants.DEFAULT_TIP_FREQUENCY_DAYS)
	last_tip_sent = models.DateTimeField(null=True, blank=True)
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(auto_now=True, db_index=True, null=True)
	last_share_upsell = models.DateTimeField(null=True, blank=True)
	last_feedback_prompt = models.DateTimeField(null=True, blank=True)

	TEMP_FORMAT_CHOICES = [(x, x) for x in [keeper_constants.TEMP_FORMAT_IMPERIAL, keeper_constants.TEMP_FORMAT_METRIC]]
	temp_format = models.CharField(max_length=10, default=keeper_constants.TEMP_FORMAT_IMPERIAL, choices=TEMP_FORMAT_CHOICES)

	done_count = models.IntegerField(default=0)
	create_todo_count = models.IntegerField(default=0)

	# These are not tied to the db, and instead are single instance
	overrideKeeperNumber = None
	pastIncomingMsgs = None

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



	def getPastIncomingMsgs(self):
		if not self.pastIncomingMsgs:
			self.pastIncomingMsgs = Message.objects.filter(user=self, incoming=True).order_by('-added')
		return self.pastIncomingMsgs

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

	def wasRecentlySentMsgOfClass(self, outgoingMsgClass, num=3):
		recentOutgoing = Message.objects.filter(user=self, incoming=False).order_by("-id")[:num]

		for msg in recentOutgoing:
			if msg.classification and msg.classification == outgoingMsgClass:
				return True

		return False

	def lastIncomingMessageAutoclass(self):
		lastIncoming = self.getMessages(True, False).first()
		return lastIncoming.auto_classification

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
		orderByString = "id" if ascending else "-id"
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

	def getActiveEntries(self):
		return Entry.objects.filter(creator=self, label="#reminders", hidden=False)

	def setSharePromptHandles(self, unresolvedHandles, resolvedHandles):
		self.setStateData("unresolvedHandles", unresolvedHandles)
		self.setStateData("sharePromptHandles", resolvedHandles)
		self.save()

	def getSharePromptHandles(self):
		unresolvedHandles = self.getStateData("unresolvedHandles")
		resolvedHandles = self.getStateData("sharePromptHandles")
		return (
			unresolvedHandles if unresolvedHandles is not None else [],
			resolvedHandles if resolvedHandles is not None else []
		)

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
	history = HistoricalRecords()
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
	use_digest_time = models.BooleanField(default=False)

	RECURRENCE_CHOICES = [(x, x) for x in keeper_constants.RECURRENCE_CHOICES]
	remind_recur = models.CharField(max_length=100, choices=RECURRENCE_CHOICES, default=keeper_constants.RECUR_DEFAULT)
	remind_recur_end = models.DateTimeField(null=True, blank=True)

	hidden = models.BooleanField(default=False)

	manually_updated = models.BooleanField(default=False)
	manually_updated_timestamp = models.DateTimeField(null=True, blank=True)

	STATE_CHOICES = [(x, x) for x in keeper_constants.ALL_REMINDER_STATES]
	state = models.CharField(max_length=100, choices=STATE_CHOICES, default=keeper_constants.REMINDER_STATE_NORMAL)
	last_state_change = models.DateTimeField(null=True, blank=True)

	# manually = True means that it needs to be reviewed
	manually_check = models.BooleanField(default=False)
	manually_approved_timestamp = models.DateTimeField(null=True, blank=True)

	created_from_entry_id = models.IntegerField(null=True, blank=True)

	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)
	updated = models.DateTimeField(db_index=True, null=True)

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
	def fetchEntries(cls, user, label=None, hidden=False, orderByString="added", state=None):
		entries = Entry.objects.filter(Q(users__in=[user]) | Q(creator=user)).order_by(orderByString).distinct()
		if hidden is not None:
			entries = entries.filter(hidden=hidden)
		if label:
			entries = entries.filter(label__iexact=label)
		if state:
			entries = entries.filter(state=keeper_constants.REMINDER_STATE_NORMAL)
		return entries

	@classmethod
	def fetchReminders(cls, user, hidden=False, orderByString="added", state=None):
		return Entry.fetchEntries(user, keeper_constants.REMIND_LABEL, hidden, orderByString, state)

	@classmethod
	def createEntry(cls, user, keeper_number, label, text, img_url=None, remind_timestamp=None):
		entry = Entry.objects.create(creator=user, label=label, text=text, img_url=img_url, remind_timestamp=remind_timestamp)
		entry.users.add(user)
		return entry

	@classmethod
	def createReminder(cls, user, text, remind_timestamp):
		entry = Entry.objects.create(creator=user, label=keeper_constants.REMIND_LABEL, text=text, remind_timestamp=remind_timestamp)
		entry.users.add(user)
		return entry

	def getOtherUserNames(self, user):
		otherUsers = set(self.users.all())
		otherUsers.remove(user)
		otherUserNames = []
		for otherUser in otherUsers:
			contact = Contact.fetchByTarget(user, otherUser)
			if contact:
				otherUserNames.append(contact.displayName())
			elif otherUser.name:
				otherUserNames.append(otherUser.name)

		return otherUserNames

	def setRemindTime(self, newDateTime, useDigestTime=False):
		datetimeToSave = newDateTime
		if useDigestTime:
			localRemindTime = datetimeToSave.astimezone(self.creator.getTimezone())
			localRemindTime.replace(hour=self.creator.digest_hour, minute=self.creator.digest_hour)
			datetimeToSave = localRemindTime.astimezone(pytz.utc)
			self.use_digest_time = True
		self.remind_timestamp = datetimeToSave

	# override save and clear use_digest_time if the remind timestamp has changed
	# from http://stackoverflow.com/questions/1355150/django-when-saving-how-can-you-check-if-a-field-has-changed
	def save(self, *args, **kw):
		if self.pk is not None:
			orig = Entry.objects.get(pk=self.pk)
			if orig.remind_timestamp and (orig.remind_timestamp != self.remind_timestamp):
				# the time_stamp has changed, see if we should clear use_digest_time
				localRemindTime = self.remind_timestamp.astimezone(self.creator.getTimezone())
				# if the new time is not your digest time, clear the use_digest_time bit
				if localRemindTime.hour != self.creator.digest_hour or localRemindTime.minute != self.creator.digest_minute:
					self.use_digest_time = False
		self.updated = date_util.now(pytz.utc)
		super(Entry, self).save(*args, **kw)

	def __str__(self):
		return "Entry %d: %s" % (self.id, str(self.__dict__))


class Message(models.Model):
	user = models.ForeignKey(User, db_index=True)
	body = models.TextField(null=True)
	msg_json = models.TextField(null=True)
	incoming = models.BooleanField(default=None)
	manual = models.BooleanField(default=None)
	classification = models.CharField(max_length=100, db_index=True, null=True, blank=True)
	auto_classification = models.CharField(max_length=100, db_index=True, null=True, blank=True)

	# manually = True means that it needs to be reviewed
	manually_check = models.BooleanField(default=False)
	manually_approved_timestamp = models.DateTimeField(null=True, blank=True)

	classification_scores_json = models.CharField(max_length=1000, null=True, blank=True)
	added = models.DateTimeField(db_index=True, null=True)
	updated = models.DateTimeField(db_index=True, null=True)

	natty_result_pkl = models.TextField(null=True)

	# calculated attributes
	messageDict = None

	def save(self, *args, **kwargs):
		# On save, update timestamps
		if not self.id:
			self.added = date_util.now()
		self.updated = date_util.now()
		return super(Message, self).save(*args, **kwargs)

	def getBody(self):
		return self.getMessageAttribute("Body")

	@classmethod
	def getClassifiedAs(cls, classification):
		return Message.objects.filter(classification=classification)

	@classmethod
	def recentIncomingMessagesForUserWithClassification(cls, user):
		recentIncoming = Message.objects.filter(user=user, incoming=True, classification__isnull=False).order_by("-id")[:3]
		return recentIncoming

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

	def activeEntriesSnapshot(self):
		dateFilter = self.added
		if not dateFilter:
			dateFilter = self.updated
		try:
			historicalEntries = Entry.history.filter(history_date__lt=dateFilter, creator=self.user).order_by('id', '-history_id')
		except:
			logger.error("Historical entries filter for message %d raised error", self.id)
			historicalEntries = []
		lastSeenId = 0
		result = []

		for historicalEntry in historicalEntries:
			if historicalEntry.id == lastSeenId:
				continue
			else:
				lastSeenId = historicalEntry.id

			if not historicalEntry.hidden:
				# we reverse sorted by history_id, so this should be the most recent historical entry before
				# the message was sent
				result.append(historicalEntry)

		return result

	def userSnapshot(self):
		dateFilter = self.added
		if not dateFilter:
			dateFilter = self.updated
		try:
			userSnapshot = User.history.filter(history_date__lt=dateFilter, id=self.user.id).order_by('history_id').last()
		except:
			logger.error("Historical user filter for message %d raised error", self.id)
			return None
		return userSnapshot

	def recentOutgoingMessageClasses(self):
		recentOutgoing = Message.objects.filter(user=self.user, incoming=False, id__lt=self.id).order_by("-added")[:3]
		result = []
		for message in recentOutgoing:
			if message.classification:
				result.append(message.classification)
		return result


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

	def displayName(self):
		if keeper_constants.RELATIONSHIP_RE.match(self.handle):
			return "your %s" % self.handle
		else:
			return self.handle.title()

	@classmethod
	def resolveHandles(cls, user, handles):
		if type(handles) is not list:
			raise NameError("Fetch by handles takes a list of handles")
		# convert all handles to lowercase
		handles = map(lambda handle: handle.lower(), handles)
		contacts = Contact.objects.filter(user=user, handle__in=handles)

		# dedupe by targets and figure out which were
		seenTargetIds = set()
		resolvedContacts = list()
		unresolvedHandles = set(handles)
		for contact in contacts:
			if contact.target.id not in seenTargetIds:
				seenTargetIds.add(contact.target.id)
				resolvedContacts.append(contact)
			unresolvedHandles.remove(contact.handle)

		return resolvedContacts, list(unresolvedHandles)

	@classmethod
	def fetchByHandle(cls, user, handle):
		try:
			handle = handle.lower()
			contacts = Contact.objects.filter(user=user, handle=handle)
			contact = None if len(contacts) == 0 else contacts[0]
			if len(contacts) > 1:
				logger.error("User %d: fetchByHandle %s returned multiple contacts", user.id, handle)

			return contact
		except Contact.DoesNotExist:
			return None

	@classmethod
	def fetchByTarget(cls, user, target):
		try:
			contacts = Contact.objects.filter(user=user, target=target)
			contact = None if len(contacts) == 0 else contacts[0]
			if len(contacts) > 1:
				logger.debug("User %d: fetchByTarget %d returned multiple contacts", user.id, target.id)
			return contact
		except Contact.DoesNotExist:
			return None

	def save(self, *args, **kw):
		self.handle = self.handle.lower()  # ensure all handles are lowercase
		super(Contact, self).save(*args, **kw)


class ZipData(models.Model):
	city = models.CharField(max_length=100)
	state = models.CharField(max_length=100)
	country_code = models.CharField(max_length=10, null=True)
	postal_code = models.CharField(max_length=10, db_index=True)
	area_code = models.CharField(max_length=10, db_index=True)
	timezone = models.CharField(max_length=30)
	wxcode = models.CharField(max_length=10, null=True)
	TEMP_FORMAT_CHOICES = [(x, x) for x in [keeper_constants.TEMP_FORMAT_IMPERIAL, keeper_constants.TEMP_FORMAT_METRIC]]
	temp_format = models.CharField(max_length=10, default=keeper_constants.TEMP_FORMAT_METRIC, choices=TEMP_FORMAT_CHOICES)


class VerbData(models.Model):
	base = models.CharField(max_length=40)
	past = models.CharField(max_length=40, db_index=True)
	past_participle = models.CharField(max_length=40, db_index=True)
	s_es_ies = models.CharField(max_length=40)
	ing = models.CharField(max_length=40)


class SimulationRun(models.Model):
	username = models.CharField(max_length=10)
	git_revision = models.CharField(max_length=7)
	source = models.CharField(max_length=1, choices=[('p', 'prod'), ('d', 'dev'), ('l', 'local')])
	sim_type = models.CharField(
		max_length=2,
		choices=[('pp', 'prodpush'), ('dp', 'devpush'), ('t', 'test'), ('nl', 'nightly')],
		db_index=True
	)
	annotation = models.TextField(null=True, blank=True)
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)

	def simResults(self):
		return SimulationResult.objects.filter(run=self)

	def numCorrect(self):
		return self.correctResults().count()

	def correctResults(self):
		return self.simResults().filter(message_classification=F('sim_classification'))

	def numIncorrect(self):
		return self.incorrectResults().count()

	def incorrectResults(self):
		return self.simResults().exclude(message_classification=F('sim_classification'))

	def recentComparableRuns(self):
		comparableTypes = [self.sim_type]
		if self.sim_type == 't':
			comparableTypes = ['pp', 'dp', 't']
		elif self.sim_type == 'dp':
			comparableTypes = ['pp', 'dp']

		recentRuns = SimulationRun.objects.filter(
			source=self.source,
			sim_type__in=comparableTypes,
			id__lt=self.id
		)
		recentRuns = recentRuns.order_by("-id")[:3]
		logger.info("returning last comparable run %s", recentRuns)
		return recentRuns

	def compareToRun(self, otherRun):
		myResults = self.simResults().order_by('message_id')
		myResultsByMessageId = {}
		for result in myResults:
			myResultsByMessageId[result.message_id] = result

		otherResults = SimulationResult.objects.filter(run=otherRun).order_by('message_id')
		differentResults = []
		for otherResult in otherResults:
			myResult = myResultsByMessageId.get(otherResult.message_id, None)
			if not myResult:
				continue

			if myResult.sim_classification == otherResult.sim_classification:
				continue

			differentResults.append(myResult)

		return SimulationResult.simulationClassDetails(differentResults)



class SimulationResult(models.Model):
	message_classification = models.CharField(max_length=100, null=True, blank=True)
	message_auto_classification = models.CharField(max_length=100, null=True, blank=True)
	message_id = models.IntegerField()
	message_body = models.TextField(null=True, blank=True)
	run = models.ForeignKey(SimulationRun, null=True)
	sim_classification = models.CharField(max_length=100, null=True, blank=True)
	sim_classification_scores_json = models.CharField(max_length=1000, null=True, blank=True)
	added = models.DateTimeField(auto_now_add=True, db_index=True, null=True)

	def isCorrect(self):
		return self.message_classification == self.sim_classification

	def recentComparableResults(self):
		recentComparable = SimulationResult.objects.filter(
			id__lt=self.id,
			message_id=self.message_id,
			run__source=self.run.source
		).order_by("-id")
		return recentComparable

	@classmethod
	def resultsByClass(cls, queryset):
		results = {}
		for simResult in queryset:
			simClass = simResult.message_classification
			resultsForClass = results.get(simClass, [])
			resultsForClass.append(simResult)
			results[simClass] = resultsForClass

		return results

	@classmethod
	def simulationClassDetails(cls, qs):
		classSummaries = {}
		for messageClass in keeper_constants.ALL_CLASS_OPTIONS:
			classSummaries[messageClass] = SimulationClassDetails(messageClass)

		for simResult in qs:
			if simResult.isCorrect():
				details = classSummaries.get(
					simResult.message_classification,
					SimulationClassDetails(simResult.message_classification)
				)
				details.tp.append(simResult)
				classSummaries[details.messageClass] = details
				SimulationClassDetails.addTrueNegativeToSummaries(
					simResult,
					classSummaries,
					exclude=[simResult.message_classification]
				)
			else:
				messageClassDetails = classSummaries.get(
					simResult.message_classification,
					SimulationClassDetails(simResult.message_classification)
				)
				simClassDetails = classSummaries.get(
					simResult.sim_classification,
					SimulationClassDetails(simResult.sim_classification)
				)
				messageClassDetails.fn.append(simResult)
				simClassDetails.fp.append(simResult)
				classSummaries[messageClassDetails.messageClass] = messageClassDetails
				classSummaries[simClassDetails.messageClass] = simClassDetails

				SimulationClassDetails.addTrueNegativeToSummaries(
					simResult,
					classSummaries,
					exclude=[simResult.message_classification, simResult.sim_classification]
				)

		return classSummaries


class SimulationClassDetails:
	messageClass = ""

	def __init__(self, messageClass):
		self.messageClass = messageClass
		self.tp = []
		self.tn = []
		self.fp = []
		self.fn = []

	@classmethod
	def addTrueNegativeToSummaries(cls, trueNegative, summariesByClass, exclude=[]):
		for otherClass in summariesByClass.keys():
			if otherClass in exclude:
				continue
			else:
				summariesByClass[otherClass].tn.append(trueNegative)

	@classmethod
	def dictRepsForSummaries(cls, summariesByClass):
		result = {}
		for key in summariesByClass.keys():
			result[key] = summariesByClass[key].summaryJsonDict()

		return result

	def countOf(self, field):
		return float(len(getattr(self, field)))

	def simpleAccuracy(self):
		if self.countOf('tp') + self.countOf('fn') > 0:
			val = self.countOf('tp') / (self.countOf('tp') + self.countOf('fn'))
			return val
		else:
			return None

	def precision(self):
		if (self.countOf('tp') + self.countOf('fp')) > 0:
			return self.countOf('tp') / (self.countOf('tp') + self.countOf('fp'))
		return None

	def recall(self):
		if (self.countOf('tp') + self.countOf('fn')):
			return self.countOf('tp') / (self.countOf('tp') + self.countOf('fn'))
		return None

	def f1(self):
		p = self.precision()
		r = self.recall()
		if (p and r):
			return (2 * p * r) / (p + r)
		return None

	def summaryJsonDict(self):
		return {
			"messageClass": self.messageClass,
			"tp": len(self.tp),
			"fp": len(self.fp),
			"fn": len(self.fn),
			"simpleAccuracy": self.simpleAccuracy(),
			"precision": self.precision(),
			"recall": self.recall(),
			"f1": self.f1()
		}

	def fullJsonDict(self, includePositives=False):
		result = self.summaryJsonDict()
		result['fpMessages'] = []
		result['fnMessages'] = []
		for simResult in self.fp:
			result['fpMessages'].append({
				"sim_result_id": simResult.id,
				"message_id": simResult.message_id,
				"body": simResult.message_body,
				"class": simResult.message_classification,
			})
		for simResult in self.fn:
			result['fnMessages'].append({
				"sim_result_id": simResult.id,
				"message_id": simResult.message_id,
				"body": simResult.message_body,
				"sim_class": simResult.sim_classification
			})
		if includePositives:
			result['tpMessages'] = []
			for simResult in self.tp:
				result['tpMessages'].append({
					"sim_result_id": simResult.id,
					"message_id": simResult.message_id,
					"body": simResult.message_body
				})

		return result

	def __str__(self):
		return "SimulationClassSummary for %s: tp:%d tn:%d fp:%d fn:%d" % (
			self.messageClass,
			len(self.tp),
			len(self.tn),
			len(self.fp),
			len(self.fn),
		)

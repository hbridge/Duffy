import datetime
import pytz
from smskeeper.models import Entry
from smskeeper import keeper_constants
from smskeeper import analytics
from smskeeper import time_utils


class KeeperTip():
	id = None
	message = None

	def __init__(self, id, message, type, mediaUrl=None):
		self.id = id
		self.message = message
		self.mediaUrl = mediaUrl
		self.type = type

	# Render a tip for a full tip, like vcard
	def render(self, user):
		if self.id == VCARD_TIP_ID:
			self.mediaUrl = getKeeperVCard(user)
		result = self.message
		result = result.replace(":NAME:", user.name)
		result = result.replace(":APP_URL:", user.getWebAppURL())
		result += "\n\n" + SMSKEEPER_TIP_FOOTER
		return result

	# Mini tips are little sentences sent after first actions
	def renderMini(self):
		return self.message

FULL_TIP_TYPE = "full"
MINI_TIP_TYPE = "mini"

REMINDER_TIP_ID = "reminders"
WEB_APP_TIP_ID = "webapp"
PHOTOS_TIP_ID = "photos"
SHARING_TIP_ID = "sharing"
VOICE_TIP_ID = "voice"
VCARD_TIP_ID = "vcard"
DONE_ALL_TIP_ID = "done-all"

SNOOZE_TIP_ID = "mini-snooze"

# Hack(Derek), doesn't really need 3 different ones, just easier than counting in user settings
DONE_TIP1_ID = "mini-done1"
DONE_TIP2_ID = "mini-done2"
DONE_TIP3_ID = "mini-done3"


# Full-tips will be evaluated for sending based on order in the array, so be sure they're in the right spot!
SMSKEEPER_TIPS = [
	KeeperTip(  # mediaurl will be put in at render time
		VCARD_TIP_ID,
		"Hey :NAME:, here's my card.  Tap it and save me to your address book so it's easier to txt me!",
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		WEB_APP_TIP_ID,
		"Hi :NAME:! Here's a handy place to manage all the stuff I've saved for you :APP_URL: It works on your :computer: too!",
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		DONE_ALL_TIP_ID,
		"Pro tip: You can also say 'Done with everything' to mark all items as done.",
		type=MINI_TIP_TYPE
	),
	#KeeperTip(
	#	PHOTOS_TIP_ID,
	#	u"I \U0001F499 pics!",
	#	type=FULL_TIP_TYPE,
	#	mediaUrl=keeper_constants.PHOTOS_TIP_URL
	#),
	# KeeperTip(
	# 	SHARING_TIP_ID,
	# 	"Hey :NAME:! I can help you keep track of stuff with friends. For example, type: 'Avengers #movie @Bob' to start a list of movies to watch with Bob."
	# ),
	KeeperTip(
		SNOOZE_TIP_ID,
		"Btw, you can always snooze a reminder by saying 'snooze for 5 mins' or 'snooze till 9pm'",
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DONE_TIP1_ID,
		"Just let me know when you're done and I'll check it off your list",
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DONE_TIP2_ID,
		"Let me know when you're done and I'll check it off for you",
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DONE_TIP3_ID,
		"Btw, let me know when you're done",
		type=MINI_TIP_TYPE
	),
]

SMSKEEPER_TIP_FOOTER = "Want fewer tips? Type 'send me tips weekly/monthly/never'"
SMSKEEPER_TIP_HOUR = 18


def isEligibleForTip(user):
	if not user.completed_tutorial:
		return False
	if user.disable_tips or user.tip_frequency_days == 0:
		return False

	# figure out if it's the right local time for tips
	now = datetime.datetime.now(pytz.utc)
	localdt = now.astimezone(user.getTimezone())  # we do this to get around mocking, as tests mock datetime.now()
	localHour = localdt.hour
	# print "now: %s usernow: %s usertz: %s sendhour: %d" % (now, localdt, user.getTimezone(), SMSKEEPER_TIP_HOUR)
	if localHour != SMSKEEPER_TIP_HOUR:
		return

	# only send tips if the user has been active or last tip was sent > their preference for days
	tip_frequency_seconds = (user.tip_frequency_days * 24 * 60 * 60) - (60 * 60)  # - is a fudge factor of an hour
	if not user.last_tip_sent:
		dt_activated = datetime.datetime.now(pytz.utc) - user.activated  # must use datetime.datetime.now and not utcnow as the test mocks datetime.now
		if dt_activated.total_seconds() >= 3 * 60 * 60:  # if it's been at least 3 hours since they signed up, send them the first tip
			return True
	else:
		dt_tip_sent = datetime.datetime.now(pytz.utc) - user.last_tip_sent  # must use datetime.datetime.now and not utcnow as the test mocks datetime.now
		# print "dt_activated: %s" % dt_tip_sent
		if dt_tip_sent.total_seconds() >= tip_frequency_seconds:
			return True
	return False


#
# Selects a full tip and returns its identifier
#
def selectNextFullTip(user):
	if not isEligibleForTip(user):
		return None

	# Filter to only full tips
	fullTips = filter(lambda tip: tip.type == FULL_TIP_TYPE, SMSKEEPER_TIPS)
	unsentTipIds = map(lambda tip: tip.id, fullTips)

	unsentTipIds = [x for x in unsentTipIds if x not in getSentTipIds(user)]
	for tipId in unsentTipIds:
		if tipId == "reminders":
			reminderCount = Entry.objects.filter(creator=user, remind_timestamp__isnull=False).count()
			if reminderCount == 0:
				return tipWithId(tipId)
		elif tipId == "photos":
			photoCount = Entry.objects.filter(creator=user, img_url__isnull=False).count()
			if photoCount == 0:
				return tipWithId(tipId)
		elif tipId == "sharing":
			hasShared = False
			entries = Entry.objects.filter(creator=user)
			for entry in entries:
				if entry.users.all().count() > 1:
					hasShared = True
					break
			if not hasShared:
				return tipWithId(tipId)
		else:
			return tipWithId(tipId)


def tipWithId(tipId):
	for tip in SMSKEEPER_TIPS:
		if tip.id == tipId:
			return tip
	return None


# isMini means that its a mini message so we don't record the last time it was sent, just that it was
def markTipSent(user, tip, customSentDate=None, isMini=False):
	date = customSentDate if customSentDate is not None else datetime.datetime.now(pytz.utc)
	sentTips = getSentTipIds(user)
	if tip.id not in sentTips:
		sentTips.append(tip.id)
		user.sent_tips = ",".join(sentTips)

		if not isMini:
			user.last_tip_sent = date
		user.save()
		logTipSent(user, tip, customSentDate, isMini, sentTips)


def getSentTipIds(user):
	if user.sent_tips:
		return user.sent_tips.split(",")
	return []


def logTipSent(user, tip, customSentDate, isMini, sentTips):
	# figure out when the last incoming message came in
	messages = user.getMessages(incoming=True, ascending=False)
	if messages and len(messages) > 0:
		lastMessage = messages[0]
		lastMessageHoursAgo = time_utils.totalHoursAgo(lastMessage.added)
	else:
		lastMessageHoursAgo = None

	# figure out local hour for the user
	now = datetime.datetime.now(pytz.utc)
	localdt = now.astimezone(user.getTimezone())
	localHour = localdt.hour

	analytics.logUserEvent(
		user,
		"Tip Received",
		{
			"Tip ID": tip.id,
			"Type": "Mini" if isMini else "Regular",
			"Last Incoming Hours Ago": lastMessageHoursAgo,
			"Total Tips Received": len(sentTips),
			"User Tip Frequency Days": user.tip_frequency_days,
			"Local Hour of Day": localHour
		},
	)


def getKeeperVCard(user):
	if user.product_id == 1:
		return keeper_constants.KEEPER_TODO_VCARD_URL
	else:
		return keeper_constants.KEEPER_VCARD_URL

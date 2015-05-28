import datetime
import pytz
from smskeeper.models import Entry
from smskeeper import keeper_constants

'''
Tips that will be sent daily to new users.
Tips will be evaluated for sending based on order so new tips should be added to the end.
'''
class KeeperTip():
	id = None
	message = None

	def __init__(self, id, message, triggerBased, mediaUrl=None):
		self.id = id
		self.message = message
		self.mediaUrl = mediaUrl
		self.triggerBased = triggerBased

	# Render a tip for a full tip, like vcard
	def render(self, name):
		return self.message.replace(":NAME:", name) + "\n\n" + SMSKEEPER_TIP_FOOTER

	# Mini tips are little sentences sent after first actions
	def renderMini(self):
		return self.message

REMINDER_TIP_ID = "reminders"
PHOTOS_TIP_ID = "photos"
SHARING_TIP_ID = "sharing"
VOICE_TIP_ID = "voice"
VCARD_TIP_ID = "vcard"

SNOOZE_TIP_ID = "mini-snooze"


SMSKEEPER_TIPS = [
	KeeperTip(
		VCARD_TIP_ID,
		"Hey :NAME:, here's my card.  Tap it and save me to your address book so it's easier to txt me!",
		keeper_constants.KEEPER_VCARD_URL,
		True
	),
	KeeperTip(
		REMINDER_TIP_ID,
		"Hi :NAME:. Just an FYI that I can set reminders for you. For example: 'remind me to call mom tomorrow at 5pm')",
		True
	),
	KeeperTip(
		PHOTOS_TIP_ID,
		u"I \U0001F499 pics!  Try sending me a selfie with 'add to selifes' and I'll store it for you.  It's a fast way to save documents and receipts, too!",
		True
	),
	# KeeperTip(
	# 	SHARING_TIP_ID,
	# 	"Hey :NAME:! I can help you keep track of stuff with friends. For example, type: 'Avengers #movie @Bob' to start a list of movies to watch with Bob."
	# ),
	KeeperTip(
		VOICE_TIP_ID,
		"If you hate typing, :NAME:, you can text me without typing a word! On an iPhone, try holding down your home button and saying 'text Keeper remind me to call Mom this weekend'",
		True
	),
	KeeperTip(
		SNOOZE_TIP_ID,
		"btw, you can always snooze a reminder by saying 'snooze 5 mins' or 'snooze 9pm'",
		False
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
		# print "user.activated %s dt_activated: %s" % (user.activated, dt_activated)
		if dt_activated.total_seconds() >= tip_frequency_seconds:
			return True
	else:
		dt_tip_sent = datetime.datetime.now(pytz.utc) - user.last_tip_sent  # must use datetime.datetime.now and not utcnow as the test mocks datetime.now
		# print "dt_activated: %s" % dt_tip_sent
		if dt_tip_sent.total_seconds() >= tip_frequency_seconds:
			return True
	return False


#
# Selects a tip and returns its identifier for trigger based tips
#
def selectNextTip(user):
	if not isEligibleForTip(user):
		return None

	# Filter to only trigger based ones
	triggerBasedTips = filter(lambda tip: tip.triggerBased, SMSKEEPER_TIPS)
	unsentTipIds = map(lambda tip: tip.id, triggerBasedTips)

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


def getSentTipIds(user):
	if user.sent_tips:
		return user.sent_tips.split(",")
	return []

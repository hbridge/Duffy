import datetime
import pytz
from smskeeper.models import Entry

'''
Tips that will be sent daily to new users.
Tips will be evaluated for sending based on order so new tips should be added to the end.
'''
class KeeperTip():
	id = None
	message = None

	def __init__(self, id, message):
		self.id = id
		self.message = message

	def render(self, name):
		return self.message.replace(":NAME:", name) + "\n\n" + SMSKEEPER_TIP_FOOTER

REMINDER_TIP_ID = "reminders"
PHOTOS_TIP_ID = "photos"
SHARING_TIP_ID = "sharing"
VOICE_TIP_ID = "voice"

SMSKEEPER_TIPS = [
	KeeperTip(
		REMINDER_TIP_ID,
		"Hey there, :NAME:. Just an FYI that I can set reminders for you. For example: 'remind me to call mom tomorrow at 5pm')"
	),
	KeeperTip(
		PHOTOS_TIP_ID,
		u"I \U0001F499 pics!  Try sending me a selfie with 'add to selifes' and I'll store it for you.  It's a fast way to save documents and receipts, too!"
	),
	# KeeperTip(
	# 	SHARING_TIP_ID,
	# 	"Hey :NAME:! I can help you keep track of stuff with friends. For example, type: 'Avengers #movie @Bob' to start a list of movies to watch with Bob."
	# ),
	KeeperTip(
		VOICE_TIP_ID,
		"Hate typing, :NAME:? Text me without without typing a word! On an iPhone, try holding down your home button and saying 'text Keeper add speak more type less to resolutions'"
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

'''
Selects a tip and returns its identifier
'''

def selectNextTip(user):
	if not isEligibleForTip(user):
		return None

	unsentTipIds = map(lambda tip: tip.id, SMSKEEPER_TIPS)
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


def markTipSent(user, tip, customSentDate=None):
	date = customSentDate if customSentDate is not None else datetime.datetime.now(pytz.utc)
	sentTips = getSentTipIds(user)
	if tip.id not in sentTips:
		sentTips.append(tip.id)
		user.sent_tips = ",".join(sentTips)
		user.last_tip_sent = date
		user.save()


def getSentTipIds(user):
	if user.sent_tips:
		return user.sent_tips.split(",")
	return []

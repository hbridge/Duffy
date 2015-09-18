import pytz
from smskeeper.models import Entry
from smskeeper import keeper_constants, keeper_strings
from smskeeper import analytics
from smskeeper import time_utils

from common import date_util


class KeeperTip():
	id = None
	message = None

	def __init__(self, id, message, type, mediaUrl=None):
		self.id = id
		self.message = message
		self.mediaUrl = mediaUrl
		self.type = type

	# Render a tip for a full tip
	def render(self, user):
		result = self.message
		result = result.replace(":NAME:", user.getFirstName())
		result = result.replace(":APP_URL:", user.getWebAppURL())
		if self.type == FULL_TIP_TYPE:
			result += "\n\n" + keeper_strings.SMSKEEPER_TIP_FOOTER
		return result

	# Mini tips are little sentences sent after first actions
	def renderMini(self):
		return self.message

	def __str__(self):
		return self.message


FULL_TIP_TYPE = "full"
MINI_TIP_TYPE = "mini"

REMINDER_TIP_ID = "reminders"
WEB_APP_TIP_ID = "webapp"
PHOTOS_TIP_ID = "photos"
SHARING_TIP_ID = "sharing"
VOICE_TIP_ID = "voice"
DONE_ALL_TIP_ID = "done-all"
PILLS_TIP_ID = "pills"
WEATHER_TIP_ID = "weather"
BIRTHDAY_TIP_ID = "birthday"
JOKE_TIP_ID = "joke"
PAY_BILLS_TIP_ID = "bills"
GROCERY_LIST_TIP_ID = "grocery-list"
TRASH_DAY_TIP_ID = "trash-day"
APPOINTMENT_TIP_ID = "appointments"
TICKETS_TIP_ID = "tickets"
TVSHOW_TIP_ID = "tv-show"
SHARED_REMINDER_TIP1_ID = "shared-reminder-1"
SHARED_REMINDER_TIP2_ID = "shared-reminder-2"
GET_TASKS_TIP_ID = "get-tasks"
WORKOUT_SCHEDULE_TIP_ID = 'workout-schedule'

SNOOZE_TIP_ID = "mini-snooze"

# Hack(Derek), doesn't really need 3 different ones, just easier than counting in user settings
DONE_TIP1_ID = "mini-done1"
DONE_TIP2_ID = "mini-done2"
DONE_TIP3_ID = "mini-done3"

DIGEST_DONE_TIP_ID = "mini-digest-done"
DIGEST_SNOOZE_TIP_ID = "mini-digest-snooze"
DIGEST_QUESTION_TIP_ID = "mini-digest-question"
DIGEST_CHANGE_TIME_TIP_ID = "mini-digest-change-time"
SHARED_REMINDER_MINI_TIP_ID = "mini-shared-reminder"
DIGEST_QUESTION_NPS_TIP_ID = "mini-digest-question-nps"
REFERRAL_ASK_TIP_ID = "mini-referral-ask"

# Full-tips will be evaluated for sending based on order in the array, so be sure they're in the right spot!
SMSKEEPER_TIPS = [
	KeeperTip(
		PILLS_TIP_ID,
		keeper_strings.PILLS_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		WEATHER_TIP_ID,
		keeper_strings.WEATHER_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		BIRTHDAY_TIP_ID,
		keeper_strings.BIRTHDAY_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		JOKE_TIP_ID,
		keeper_strings.JOKE_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		PAY_BILLS_TIP_ID,
		keeper_strings.PAY_BILLS_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		GROCERY_LIST_TIP_ID,
		keeper_strings.GROCERY_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		TRASH_DAY_TIP_ID,
		keeper_strings.TRASH_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		APPOINTMENT_TIP_ID,
		keeper_strings.APPOINTMENT_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		TICKETS_TIP_ID,
		keeper_strings.TICKET_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		SHARED_REMINDER_TIP1_ID,
		keeper_strings.SHARED_REMINDER_TIP1_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		TVSHOW_TIP_ID,
		keeper_strings.TVSHOW_TIP_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		GET_TASKS_TIP_ID,
		keeper_strings.GET_TASKS_TIP_TEXT,
		type=FULL_TIP_TYPE,
	),
	KeeperTip(
		SHARED_REMINDER_TIP2_ID,
		keeper_strings.SHARED_REMINDER_TIP2_TEXT,
		type=FULL_TIP_TYPE
	),
	KeeperTip(
		WORKOUT_SCHEDULE_TIP_ID,
		keeper_strings.WORKOUT_SCHEDULE_TEXT,
		type=FULL_TIP_TYPE
	),

	# MINI TIPS

	KeeperTip(
		DONE_ALL_TIP_ID,
		keeper_strings.DONE_ALL_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		SNOOZE_TIP_ID,
		keeper_strings.SNOOZE_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DONE_TIP1_ID,
		keeper_strings.DONE_TIP1_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DONE_TIP2_ID,
		keeper_strings.DONE_TIP2_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DONE_TIP3_ID,
		keeper_strings.DONE_TIP3_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DIGEST_DONE_TIP_ID,
		keeper_strings.REMINDER_DIGEST_DONE_INSTRUCTIONS,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DIGEST_SNOOZE_TIP_ID,
		keeper_strings.REMINDER_DIGEST_SNOOZE_INSTRUCTIONS,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DIGEST_QUESTION_TIP_ID,
		keeper_strings.DIGEST_QUESTION_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DIGEST_CHANGE_TIME_TIP_ID,
		keeper_strings.DIGEST_CHANGE_TIME_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		SHARED_REMINDER_MINI_TIP_ID,
		keeper_strings.SHARED_REMINDER_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		DIGEST_QUESTION_NPS_TIP_ID,
		keeper_strings.DIGEST_QUESTION_NPS_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
	KeeperTip(
		REFERRAL_ASK_TIP_ID,
		keeper_strings.REFERRAL_ASK_MINITIP_TEXT,
		type=MINI_TIP_TYPE
	),
]


def tipWithId(tipId):
	for tip in SMSKEEPER_TIPS:
		if tip.id == tipId:
			return tip
	return None


SMSKEEPER_TIP_HOUR = 18

DONE_MINI_TIPS_LIST = [
	tipWithId(DONE_TIP1_ID),
	tipWithId(DONE_TIP2_ID),
	tipWithId(DONE_TIP3_ID)
]


def isEligibleForTip(user):
	if not user.completed_tutorial:
		return False
	if user.disable_tips or user.tip_frequency_days == 0:
		return False

	# figure out if it's the right local time for tips
	localdt = date_util.now(user.getTimezone())  # we do this to get around mocking, as tests mock datetime.now()
	localHour = localdt.hour
	# print "now: %s usernow: %s usertz: %s sendhour: %d" % (now, localdt, user.getTimezone(), SMSKEEPER_TIP_HOUR)
	if localHour != SMSKEEPER_TIP_HOUR:
		return False
	if localdt.isoweekday() > 4:
		return False

	# only send tips if the user has been active or last tip was sent > their preference for days
	tip_frequency_seconds = (user.tip_frequency_days * 24 * 60 * 60) - (60 * 60)  # - is a fudge factor of an hour
	if not user.last_tip_sent:
		dt_activated = date_util.now(pytz.utc) - user.activated  # must use date_util.now and not utcnow as the test mocks datetime.now
		if dt_activated.total_seconds() > 10 * 60 * 60:  # if it's been at least 3 hours since they signed up, send them the first tip
			return True
	else:
		dt_tip_sent = date_util.now(pytz.utc) - user.last_tip_sent  # must use date_util.now and not utcnow as the test mocks datetime.now
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


# isMini means that its a mini message so we don't record the last time it was sent, just that it was
def markTipSent(user, tip, customSentDate=None, isMini=False):
	date = customSentDate if customSentDate is not None else date_util.now(pytz.utc)
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


def isUserEligibleForMiniTip(user, miniTipId):
	return miniTipId not in getSentTipIds(user)


def logTipSent(user, tip, customSentDate, isMini, sentTips):
	# figure out when the last incoming message came in
	messages = user.getMessages(incoming=True, ascending=False)
	if messages and len(messages) > 0:
		lastMessage = messages[0]
		lastMessageHoursAgo = time_utils.totalHoursAgo(lastMessage.added)
	else:
		lastMessageHoursAgo = None

	# figure out local hour for the user
	now = date_util.now(pytz.utc)
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

from __future__ import absolute_import
import datetime
import pytz
import time
import os
import sys
import pywapi

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from celery.utils.log import get_task_logger
from peanut.celery import app

from smskeeper import tips, sms_util, user_util, msg_util
from smskeeper.models import Entry, Message, User
from smskeeper import keeper_constants

from common import date_util

logger = get_task_logger(__name__)


# Returns true if:
# The remind timestamp ends in 0 or 30 minutes and its within 10 minutes of then
# The current time is after the remind timestamp but we're within 5 minutes
# Hidden is false
def shouldRemindNow(entry):
	# TODO: Remove this line. Leaving it in for now as a last defense against sending hidden reminders
	if entry.hidden:
		return False

	now = date_util.now(pytz.utc)

	# Don't remind if we have already send one out
	if entry.remind_last_notified:
		return False

	# Don't remind if its too far in the past
	if entry.remind_timestamp < now - datetime.timedelta(minutes=5):
		return False

	# Ddon't send a reminder if this is during the digest time, since it'll be
	# included in that
	if entry.creator.isDigestTime(entry.remind_timestamp):
		return False

	if entry.remind_timestamp.minute == 0 or entry.remind_timestamp.minute == 30:
		# If we're within 10 minutes, so alarm goes off at 9:50 if remind is at 10
		return (now + datetime.timedelta(minutes=10) > entry.remind_timestamp)
	else:
		return (now >= entry.remind_timestamp)


def processReminder(entry):
	isSharedReminder = (len(entry.users.all()) > 1)

	users = set(entry.users.all())
	users.add(entry.creator)

	for user in users:
		if user.state == keeper_constants.STATE_STOPPED:
			pass
		elif isSharedReminder and user.id == entry.creator.id:
			# Only process reminders for the non-creator
			pass
		else:
			if isSharedReminder:
				# If they've never used the system before
				if user.state == keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER:
					msg = "Hi, I'm Keeper. I'm a digital assistant. %s wanted me to remind you: %s" % (entry.creator.name, entry.text)
				else:
					msg = "Hi! Friendly reminder from %s: %s" % (entry.creator.name, entry.text)
			else:
				msg = "Hi! Friendly reminder: %s" % entry.text

			sms_util.sendMsg(user, msg, None, user.getKeeperNumber())
			entry.remind_last_notified = date_util.now(pytz.utc)

			# Only do fancy things like snooze if they've actually gone through the tutorial
			if user.completed_tutorial:
				# Hack for now until we figure out better tips for
				if tips.DONE_TIP1_ID not in tips.getSentTipIds(user):
					# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
					# sms_util for sending list of msgs
					if keeper_constants.isRealKeeperNumber(user.getKeeperNumber()):
						time.sleep(2)

					tip = tips.tipWithId(tips.DONE_TIP1_ID)
					sms_util.sendMsg(user, tip.renderMini(), None, user.getKeeperNumber())
					tips.markTipSent(user, tip, isMini=True)
				elif tips.DONE_TIP2_ID not in tips.getSentTipIds(user):
					# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
					# sms_util for sending list of msgs
					if keeper_constants.isRealKeeperNumber(user.getKeeperNumber()):
						time.sleep(2)

					tip = tips.tipWithId(tips.DONE_TIP2_ID)
					sms_util.sendMsg(user, tip.renderMini(), None, user.getKeeperNumber())
					tips.markTipSent(user, tip, isMini=True)
				elif tips.DONE_TIP3_ID not in tips.getSentTipIds(user):
					# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
					# sms_util for sending list of msgs
					if keeper_constants.isRealKeeperNumber(user.getKeeperNumber()):
						time.sleep(2)

					tip = tips.tipWithId(tips.DONE_TIP3_ID)
					sms_util.sendMsg(user, tip.renderMini(), None, user.getKeeperNumber())
					tips.markTipSent(user, tip, isMini=True)
				elif tips.SNOOZE_TIP_ID not in tips.getSentTipIds(user):
					# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
					# sms_util for sending list of msgs
					if keeper_constants.isRealKeeperNumber(user.getKeeperNumber()):
						time.sleep(2)

					tip = tips.tipWithId(tips.SNOOZE_TIP_ID)
					sms_util.sendMsg(user, tip.renderMini(), None, user.getKeeperNumber())
					tips.markTipSent(user, tip, isMini=True)

				# Now set to reminder sent, incase they send back done message
				user.setState(keeper_constants.STATE_REMINDER_SENT, override=True)
				user.setStateData(keeper_constants.LAST_ENTRIES_IDS_KEY, [entry.id])

	entry.save()


@app.task
def processAllReminders():
	entries = Entry.objects.filter(remind_timestamp__isnull=False, hidden=False)

	for entry in entries:
		if shouldRemindNow(entry):
			logger.info("Processing entry: %s for users %s" % (entry.id, entry.users.all()))
			processReminder(entry)


def shouldIncludeEntry(entry):
	# Cutoff time is 23 hours ahead, could be changed later to be more tz aware
	localNow = date_util.now(entry.creator.getTimezone())
	# Cutoff time is midnight local time
	cutoffTime = (localNow + datetime.timedelta(days=1)).replace(hour=0, minute=0)

	if not entry.hidden and entry.remind_timestamp < cutoffTime:
		return True
	return False


def getDigestMessageForUser(user, pendingEntries, weatherDataCache, isAll):
	now = date_util.now(pytz.utc)
	msg = ""

	if isAll:
		msg = u"Your current tasks: \U0001F4DD\n"
	else:
		headerPhrase = keeper_constants.REMINDER_DIGEST_HEADERS[now.weekday()]
		msg += u"%s\n" % (headerPhrase)

		if user.zipcode:
			weatherPhrase = getWeatherPhraseForZip(user.zipcode, weatherDataCache)
			if weatherPhrase:
				msg += u"\n%s\n\n" % (weatherPhrase)

		msg += u"Your tasks for today: \U0001F4DD\n"

	if len(pendingEntries) == 0:
		return None, []

	for entry in pendingEntries:
		if user.isDigestTime(entry.remind_timestamp) and now.day == entry.remind_timestamp.day:
			entry.remind_last_notified = date_util.now(pytz.utc)
			entry.save()
		msg += u"\U0001F538 " + entry.text

		if entry.remind_timestamp > now:
			msg += " (%s)" % msg_util.naturalize(now, entry.remind_timestamp.astimezone(user.getTimezone()), True)
		msg += "\n"

	return msg


@app.task
def sendDigestForUserId(userId, overrideKeeperNumber=None):
	weatherDataCache = dict()
	user = User.objects.get(id=userId)

	pendingEntries = user_util.pendingTodoEntries(user, includeAll=False)

	if len(pendingEntries) > 0:
		sendDigestForUserWithPendingEntries(user, pendingEntries, weatherDataCache, False, overrideKeeperNumber=overrideKeeperNumber)


def sendDigestForUserWithPendingEntries(user, pendingEntries, weatherDataCache, isAll, overrideKeeperNumber=None):
	if len(pendingEntries) > 0:
		keeperNumber = user.getKeeperNumber() if overrideKeeperNumber is None else overrideKeeperNumber
		msg = getDigestMessageForUser(user, pendingEntries, weatherDataCache, isAll)
		sms_util.sendMsg(user, msg, None, keeperNumber)

		# Now set to reminder sent, incase they send back done message
		user.setState(keeper_constants.STATE_REMINDER_SENT, override=True)
		user.setStateData(keeper_constants.LAST_ENTRIES_IDS_KEY, [x.id for x in pendingEntries])

		if tips.isUserEligibleForMiniTip(user, tips.DIGEST_TIP_ID):
			digestTip = tips.tipWithId(tips.DIGEST_TIP_ID)
			sendTipToUser(digestTip, user, keeperNumber)


@app.task
def sendAllRemindersForUserId(userId, overrideKeeperNumber=None):
	weatherDataCache = dict()

	user = User.objects.get(id=userId)
	pendingEntries = user_util.pendingTodoEntries(user, includeAll=True)

	if len(pendingEntries) > 0:
		sendDigestForUserWithPendingEntries(user, pendingEntries, weatherDataCache, True, overrideKeeperNumber=overrideKeeperNumber)
	else:
		sms_util.sendMsg(user, "You have no pending tasks.", None, user.getKeeperNumber())


@app.task
def processDailyDigest(startAtId=None, minuteOverride=None):
	weatherDataCache = dict()

	if startAtId:
		users = User.objects.filter(id__gt=startAtId)
	else:
		users = User.objects.all()

	for user in users:
		if user.state == keeper_constants.STATE_STOPPED or user.state == keeper_constants.STATE_SUSPENDED:
			continue

		if not user.isDigestTime(date_util.now(pytz.utc), minuteOverride):
			continue

		if not user.completed_tutorial:
			continue

		pendingEntries = user_util.pendingTodoEntries(user, includeAll=False)

		if len(pendingEntries) > 0:
			sendDigestForUserWithPendingEntries(user, pendingEntries, weatherDataCache, False)

		elif user.product_id == keeper_constants.TODO_PRODUCT_ID:
			userNow = date_util.now(user.getTimezone())
			if userNow.weekday() == 0:  # Monday
				pendingThisWeek = user_util.pendingTodoEntries(user, includeAll=True, before=userNow + datetime.timedelta(days=5))
				if len(pendingThisWeek) == 0:
					sms_util.sendMsg(user, keeper_constants.REMINDER_DIGEST_EMPTY_MONDAY, None, user.getKeeperNumber())
			elif userNow.weekday() == 4:  # Friday
				pendingThisWeekend = user_util.pendingTodoEntries(user, includeAll=True, before=userNow + datetime.timedelta(days=4))
				if len(pendingThisWeekend) == 0:
					sms_util.sendMsg(user, keeper_constants.REMINDER_DIGEST_EMPTY_FRIDAY, None, user.getKeeperNumber())


@app.task
def sendTips(overrideKeeperNumber=None):
	# TODO add test to make sure we send tips to the right number for each user
	users = User.objects.all()
	for user in users:
		if user.state == keeper_constants.STATE_STOPPED or user.state == keeper_constants.STATE_SUSPENDED:
			continue

		tip = tips.selectNextFullTip(user)
		if tip:
			keeperNumber = overrideKeeperNumber
			if not keeperNumber:
				keeperNumber = user.getKeeperNumber()
			sendTipToUser(tip, user, keeperNumber)


def sendTipToUser(tip, user, keeperNumber):
	sms_util.sendMsg(user, tip.render(user), tip.mediaUrl, keeperNumber)
	tips.markTipSent(user, tip)


def str_now_1():
	return str(datetime.now())

weatherCodes = {
	"0": u'\U0001F300',
	"1": u'\U0001F300',
	"2": u'\U0001F300\U0001F300',
	"3": u'\U000026A1\U000026A1\U00002614',
	"4": u'\U000026A1\U00002614',
	"5": u'\U0001F4A7\U00002744',
	"6": u'\U0001F4A7\U000026AA',
	"7": u'\U00002744\U000026AA',
	"8": u'\U0001F4A7',
	"9": u'\U00002614',
	"10": u'\U000026C4\U00002614',
	"11": u'\U00002614',
	"12": u'\U00002614',
	"13": u'\U00002744',
	"14": u'\U00002744\U0001F4A7',
	"15": u'\U00002744\U0001F4A8',
	"16": u'\U00002744',
	"17": u'\U0001F4A7\U00002614',
	"18": u'\U00002744',
	"19": u'\U0001F301',
	"20": u'\U0001F301',
	"21": u'\U0001F301',
	"22": u'\U0001F301',
	"23": u'\U0001F4A8\U0001F4A8',
	"24": u'\U0001F4A8',
	"25": u'\U000026C4',
	"26": u'\U00002601\U00002601',
	"27": u'\U00002601',
	"28": u'\U00002601\U000026C5',
	"29": u'\U00002601',
	"30": u'\U000026C5',
	"31": u'\U00002601',
	"32": u'\U0001F31E\U0001F31E',
	"33": u'\U00002601',
	"34": u'\U0001F31E',
	"35": u'\U00002614',
	"36": u'\U0001F630\U0001F4A6',
	"37": u'\U000026A1\U00002614',
	"38": u'\U000026A1\U00002614',
	"39": u'\U000026A1\U00002614',
	"40": u'\U00002614',
	"41": u'\U00002744\U00002744\U00002744',
	"42": u'\U00002744\U0001F4A7',
	"43": u'\U00002744\U00002744\U00002744',
	"44": u'\U000026C5',
	"45": u'\U000026A1\U00002614',
	"46": u'\U00002744\U0001F4A7',
	"47": u'\U000026A1\U00002614',
	"3200": u'\U00002601',
}


def getWeatherPhraseForZip(zipCode, weatherDataCache):
	if zipCode in weatherDataCache:
		data = weatherDataCache[zipCode]
	else:
		try:
			data = pywapi.get_weather_from_yahoo(zipCode, 'imperial')
			weatherDataCache[zipCode] = data
		except:
			data = None

	if data:
		if "forecasts" in data:
			return "Today's forecast: %s | High %s and low %s" % (weatherCodes[data["forecasts"][0]["code"]], data["forecasts"][0]["high"], data["forecasts"][0]["low"])
		else:
			logger.error("Didn't find forecase for zip %s" % zipCode)
			return None
	else:
		return None


@app.task
def testCelery():
	logger.debug("Celery task ran.")


@app.task
def suspendInactiveUsers(doit=False):
	now = date_util.now(pytz.utc)
	cutoff = now - datetime.timedelta(days=7)

	users = User.objects.exclude(state=keeper_constants.STATE_SUSPENDED).exclude(state=keeper_constants.STATE_STOPPED)
	for user in users:
		lastMessageIn = Message.objects.filter(user=user, incoming=True).order_by("added").last()

		futureReminders = user_util.pendingTodoEntries(user, includeAll=True, after=now)
		if lastMessageIn and lastMessageIn.added < cutoff and len(futureReminders) == 0:
			logger.info("Putting user %s into suspended state because last message was %s" % (user.id, lastMessageIn.added))
			if doit:
				user.setState(keeper_constants.STATE_SUSPENDED, override=True)
				user.save()


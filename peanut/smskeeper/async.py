from __future__ import absolute_import
import datetime
import pytz
import time
import os
import sys

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

	for user in entry.users.all():
		if user.state == keeper_constants.STATE_STOPPED or user.state == keeper_constants.STATE_SUSPENDED:
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
				user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entry.id)
				user.save()

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


def getDigestMessageForUser(user, pendingEntries, isAll):
	now = date_util.now(pytz.utc)

	if not isAll:
		msg = u"Your tasks for today: \U0001F4DD\n"
	else:
		msg = u"Your current tasks: \U0001F4DD\n"

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

	msg += "\nWant me to check tasks off this list? Just tell me like 'Done with calling Mom'"

	return msg


@app.task
def sendDigestForUserId(userId):
	user = User.objects.get(id=userId)

	pendingEntries = user_util.pendingTodoEntries(user, includeAll=False)

	if len(pendingEntries) > 0:
		msg = getDigestMessageForUser(user, pendingEntries, False)

		sms_util.sendMsg(user, msg, None, user.getKeeperNumber())

		# Now set to reminder sent, incase they send back done message
		user.setState(keeper_constants.STATE_REMINDER_SENT, override=True)
		user.setStateData(keeper_constants.ENTRY_IDS_DATA_KEY, [x.id for x in pendingEntries])
		user.save()


@app.task
def sendAllRemindersForUserId(userId):
	user = User.objects.get(id=userId)

	pendingEntries = user_util.pendingTodoEntries(user, includeAll=True)

	if len(pendingEntries) > 0:
		msg = getDigestMessageForUser(user, pendingEntries, True)
		sms_util.sendMsg(user, msg, None, user.getKeeperNumber())

		# Now set to reminder sent, incase they send back done message
		user.setState(keeper_constants.STATE_REMINDER_SENT, override=True)
		user.setStateData(keeper_constants.ENTRY_IDS_DATA_KEY, [x.id for x in pendingEntries])
		user.save()
	else:
		sms_util.sendMsg(user, "You have no pending tasks", None, user.getKeeperNumber())


@app.task
def processDailyDigest():
	for user in User.objects.all():
		if user.state == keeper_constants.STATE_STOPPED or user.state == keeper_constants.STATE_SUSPENDED:
			continue

		if not user.isDigestTime(date_util.now(pytz.utc)):
			continue

		if not user.completed_tutorial:
			continue

		pendingEntries = user_util.pendingTodoEntries(user, includeAll=False)

		if len(pendingEntries) > 0:
			msg = getDigestMessageForUser(user, pendingEntries, False)
			sms_util.sendMsg(user, msg, None, user.getKeeperNumber())

			# Now set to reminder sent, incase they send back done message
			user.setState(keeper_constants.STATE_REMINDER_SENT, override=True)
			user.setStateData(keeper_constants.ENTRY_IDS_DATA_KEY, [x.id for x in pendingEntries])
			user.save()
		elif user.product_id == keeper_constants.TODO_PRODUCT_ID:
			userNow = date_util.now(user.getTimezone())
			if userNow.weekday() == 0:  # Monday
				pendingThisWeek = user_util.pendingTodoEntries(user, includeAll=True, before=userNow + datetime.timedelta(days=5))
				if len(pendingThisWeek) == 0:
					sms_util.sendMsg(user, "Morning! Looks like I'm not tracking anything for you this week. What do you want to get done this week?", None, user.getKeeperNumber())
			elif userNow.weekday() == 4:  # Friday
				pendingThisWeekend = user_util.pendingTodoEntries(user, includeAll=True, before=userNow + datetime.timedelta(days=4))
				if len(pendingThisWeekend) == 0:
					sms_util.sendMsg(user, "Morning! Looks like I'm not tracking anything for you this weekend. What do you want to get done this weekend?", None, user.getKeeperNumber())


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


@app.task
def testCelery():
	logger.debug("Celery task ran.")


@app.task
def suspendInactiveUsers():
	now = date_util.now(pytz.utc)
	cutoff = now - datetime.timedelta(days=7)

	users = User.objects.exclude(state=keeper_constants.STATE_SUSPENDED).exclude(state=keeper_constants.STATE_STOPPED)
	for user in users:
		lastMessageIn = Message.objects.filter(user=user, incoming=True).order_by("-added").last()

		futureReminders = user_util.pendingTodoEntries(user, includeAll=True, after=now)
		if lastMessageIn and lastMessageIn.added < cutoff and len(futureReminders) == 0:
			logger.info("Putting user %s into suspended state" % user.id)
			user.setState(keeper_constants.STATE_SUSPENDED, override=True)
			user.save()


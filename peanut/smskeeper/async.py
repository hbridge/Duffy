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
from smskeeper.models import Entry
from smskeeper.models import User
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

	# If this is a todo, don't send a reminder if this is during the digest time, since it'll be
	# included in that
	if entry.creator.product_id == keeper_constants.TODO_PRODUCT_ID:
		if isDigestTimeForUser(entry.creator, entry.remind_timestamp):
			return False

	if entry.remind_timestamp.minute == 0 or entry.remind_timestamp.minute == 30:
		# If we're within 10 minutes, so alarm goes off at 9:50 if remind is at 10
		return (now + datetime.timedelta(minutes=10) > entry.remind_timestamp)
	else:
		return (now >= entry.remind_timestamp)


def processReminder(entry):
	isSharedReminder = (len(entry.users.all()) > 1)

	for user in entry.users.all():
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

			sms_util.sendMsg(user, msg, None, entry.keeper_number)
			entry.remind_last_notified = date_util.now(pytz.utc)

			# Only do fancy things like snooze if they've actually gone through the tutorial
			if user.completed_tutorial:
				if user.product_id == 1:
					# Hack for now until we figure out better tips for
					if tips.DONE_TIP1_ID not in tips.getSentTipIds(user):
						# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
						# sms_util for sending list of msgs
						if keeper_constants.isRealKeeperNumber(entry.keeper_number):
							time.sleep(2)

						tip = tips.tipWithId(tips.DONE_TIP1_ID)
						sms_util.sendMsg(user, tip.renderMini(), None, entry.keeper_number)
						tips.markTipSent(user, tip, isMini=True)
					elif tips.DONE_TIP2_ID not in tips.getSentTipIds(user):
						# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
						# sms_util for sending list of msgs
						if keeper_constants.isRealKeeperNumber(entry.keeper_number):
							time.sleep(2)

						tip = tips.tipWithId(tips.DONE_TIP2_ID)
						sms_util.sendMsg(user, tip.renderMini(), None, entry.keeper_number)
						tips.markTipSent(user, tip, isMini=True)
					elif tips.DONE_TIP3_ID not in tips.getSentTipIds(user):
						# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
						# sms_util for sending list of msgs
						if keeper_constants.isRealKeeperNumber(entry.keeper_number):
							time.sleep(2)

						tip = tips.tipWithId(tips.DONE_TIP3_ID)
						sms_util.sendMsg(user, tip.renderMini(), None, entry.keeper_number)
						tips.markTipSent(user, tip, isMini=True)

					# Now set to reminder sent, incase they send back done message
					user.setState(keeper_constants.STATE_REMINDER_SENT, override=True)
					user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entry.id)
					user.save()
				else:
					if tips.SNOOZE_TIP_ID not in tips.getSentTipIds(user):
						# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
						# sms_util for sending list of msgs
						if keeper_constants.isRealKeeperNumber(entry.keeper_number):
							time.sleep(2)

						tip = tips.tipWithId(tips.SNOOZE_TIP_ID)
						sms_util.sendMsg(user, tip.renderMini(), None, entry.keeper_number)
						tips.markTipSent(user, tip, isMini=True)

					# Now set to reminder sent, incase they send back snooze
					user.setState(keeper_constants.STATE_REMIND, override=True)
					user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entry.id)
					user.setStateData("reminderSent", True)
					user.save()

	# For product id 0, hide after a reminder has occured
	#if entry.creator.product_id == 0:
	#	entry.hidden = True

	entry.save()


@app.task
def processAllReminders():
	entries = Entry.objects.filter(remind_timestamp__isnull=False, hidden=False)

	for entry in entries:
		if shouldRemindNow(entry):
			logger.info("Processing entry: %s for users %s" % (entry.id, entry.users.all()))
			processReminder(entry)


# Returns true if the user should be sent the digest at the given utc time
def isDigestTimeForUser(user, utcTime):
	localTime = utcTime.astimezone(user.getTimezone())

	# By default only send if its 9 am
	# Later on might make this per-user specific
	if localTime.hour == keeper_constants.TODO_DIGEST_HOUR and localTime.minute == keeper_constants.TODO_DIGEST_MINUTE:
		return True
	return False


def shouldIncludeEntry(entry):
	# Cutoff time is 23 hours ahead, could be changed later to be more tz aware
	localNow = date_util.now(entry.creator.getTimezone())
	# Cutoff time is midnight local time
	cutoffTime = (localNow + datetime.timedelta(days=1)).replace(hour=0, minute=0)

	if not entry.hidden and entry.remind_timestamp < cutoffTime:
		return True
	return False


def getDigestMessageForUser(user, entries):
	now = date_util.now(pytz.utc)
	msg = "Your things for today:\n"
	pendingEntries = user_util.pendingTodoEntries(user, entries)
	if len(pendingEntries) == 0:
		return "", []

	for entry in pendingEntries:
		if isDigestTimeForUser(user, entry.remind_timestamp):
			entry.remind_last_notified = date_util.now(pytz.utc)
			entry.save()
		msg += entry.text

		if entry.remind_timestamp > now:
			msg += " (%s)" % msg_util.getNaturalTime(entry.remind_timestamp.astimezone(user.getTimezone()))
		msg += "\n"

	msg += "\nLet me know, when you are done with a task. Like 'Done with calling Mom'"

	return msg, pendingEntries


@app.task
def sendDigestForUserId(userId):
	user = User.objects.get(id=userId)

	msg, pendingEntries = getDigestMessageForUser(user, None)

	if msg:
		sms_util.sendMsg(user, msg, None, user.getKeeperNumber())

		# Now set to reminder sent, incase they send back done message
		user.setState(keeper_constants.STATE_REMINDER_SENT, override=True)
		user.setStateData(keeper_constants.ENTRY_IDS_DATA_KEY, [x.id for x in pendingEntries])
		user.save()


@app.task
def processDailyDigest(keeperNumber=None):
	entries = Entry.objects.filter(creator__product_id=1, label="#reminders", hidden=False)
	entriesByCreator = dict()

	for entry in entries:
		if entry.creator not in entriesByCreator:
			entriesByCreator[entry.creator] = list()
		entriesByCreator[entry.creator].append(entry)

	for user, entries in entriesByCreator.iteritems():
		if user.state == keeper_constants.STATE_STOPPED:
			continue

		if not isDigestTimeForUser(user, date_util.now(pytz.utc)):
			continue

		msg, pendingEntries = getDigestMessageForUser(user, entries)

		if not keeperNumber:
			keeperNumber = user.getKeeperNumber()

		if msg:
			sms_util.sendMsg(user, msg, None, keeperNumber)

			# Now set to reminder sent, incase they send back done message
			user.setState(keeper_constants.STATE_REMINDER_SENT, override=True)
			user.setStateData(keeper_constants.ENTRY_IDS_DATA_KEY, [x.id for x in pendingEntries])
			user.save()
		else:
			sms_util.sendMsg(user, "fyi, there's nothing I'm tracking for you today. If something comes up, txt me", None, user.getKeeperNumber())


@app.task
def sendTips(overrideKeeperNumber=None):
	# TODO add test to make sure we send tips to the right number for each user
	users = User.objects.all()
	for user in users:
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

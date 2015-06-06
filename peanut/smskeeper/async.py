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

from django.conf import settings

from celery.utils.log import get_task_logger
from peanut.celery import app

from smskeeper import tips, sms_util, user_util, msg_util
from smskeeper.models import Entry
from smskeeper.models import User
from smskeeper import keeper_constants

logger = get_task_logger(__name__)


# Returns true if:
# The remind timestamp ends in 0 or 30 minutes and its within 10 minutes of then
# The current time is after the remind timestamp but we're within 5 minutes
# Hidden is false
def shouldRemindNow(entry):
	if entry.hidden:
		return False

	now = datetime.datetime.now(pytz.utc)

	# Don't remind if we sent one since the last time it was updated/created
	if entry.remind_last_notified and entry.updated:
		return False

	# Don't remind if its too far in the past
	if entry.remind_timestamp < now - datetime.timedelta(minutes=5):
		return False

	if entry.remind_timestamp.minute == 0 or entry.remind_timestamp.minute == 30:
		# If we're within 10 minutes, so alarm goes off at 9:50 if remind is at 10
		return (now + datetime.timedelta(minutes=10) > entry.remind_timestamp)
	else:
		return (now > entry.remind_timestamp)


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
			entry.remind_last_notified = datetime.datetime.now(pytz.utc)

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
					user.setState(keeper_constants.STATE_REMINDER_SENT, saveCurrent=True)
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
					user.setState(keeper_constants.STATE_REMIND, saveCurrent=True)
					user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entry.id)
					user.setStateData("reminderSent", True)
					user.save()

	# For product id 0, hide after a reminder has occured
	if entry.creator.product_id == 0:
		entry.hidden = True

	entry.save()


@app.task
def processAllReminders():
	entries = Entry.objects.filter(remind_timestamp__isnull=False, hidden=False)

	for entry in entries:
		if shouldRemindNow(entry):
			logger.info("Processing entry: %s for users %s" % (entry.id, entry.users.all()))
			processReminder(entry)


def shouldSendDigestForUser(user):
	localNow = datetime.datetime.now(user.getTimezone())

	# By default only send if its 9 am
	# Later on might make this per-user specific
	if localNow.hour == 9 and localNow.minute == 0:
		return True
	return False


def shouldIncludeEntry(entry):
	# Cutoff time is 23 hours ahead, could be changed later to be more tz aware
	localNow = datetime.datetime.now(entry.creator.getTimezone())
	# Cutoff time is midnight local time
	cutoffTime = (localNow + datetime.timedelta(days=1)).replace(hour=0, minute=0)

	if not entry.hidden and entry.remind_timestamp < cutoffTime:
		return True
	return False


def getDigestMessageForUser(user, entries):
	now = datetime.datetime.now(pytz.utc)
	msg = "Your things for today:\n"
	pendingEntries = user_util.pendingTodoEntries(user, entries)
	for entry in pendingEntries:
		entry.remind_last_notified = datetime.datetime.now(pytz.utc)
		entry.save()
		msg += entry.text

		if entry.remind_timestamp > now:
			msg += " at %s" % msg_util.getNaturalTime(entry.remind_timestamp.astimezone(user.getTimezone()))
		msg += "\n"

	msg += "\nJust say 'done with...' aftewards!"

	return msg


@app.task
def sendDigestForUserId(userId):
	user = User.objects.get(id=userId)

	msg = getDigestMessageForUser(user, None)

	if msg:
		sms_util.sendMsg(user, msg, None, settings.KEEPER_NUMBER)


@app.task
def processDailyDigest():
	entries = Entry.objects.filter(creator__product_id=1, label="#reminders", hidden=False)

	entriesByCreator = dict()

	for entry in entries:
		if entry.creator not in entriesByCreator:
			entriesByCreator[entry.creator] = list()
		entriesByCreator[entry.creator].append(entry)

	for user, entries in entriesByCreator.iteritems():
		if not shouldSendDigestForUser(user):
			pass

		msg = getDigestMessageForUser(user, entries)

		if msg:
			sms_util.sendMsg(user, msg, None, settings.KEEPER_NUMBER)


@app.task
def sendTips(keeperNumber=None):
	if not keeperNumber:
		keeperNumber = settings.KEEPER_NUMBER

	users = User.objects.all()
	for user in users:
		tip = tips.selectNextTip(user)
		if tip:
			sendTipToUser(tip, user, keeperNumber)


def sendTipToUser(tip, user, keeperNumber):
	sms_util.sendMsg(user, tip.render(user.name), tip.mediaUrl, keeperNumber)
	tips.markTipSent(user, tip)


def str_now_1():
	return str(datetime.now())


@app.task
def testCelery():
	logger.debug("Celery task ran.")

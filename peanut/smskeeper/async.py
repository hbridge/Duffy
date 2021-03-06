from __future__ import absolute_import
import datetime
import pytz
import random
import time
import os
import sys

from dateutil.relativedelta import relativedelta

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from celery.utils.log import get_task_logger
from peanut.celery import app

from smskeeper import tips, sms_util, user_util, msg_util
from smskeeper.models import Entry, Message, User
from smskeeper import keeper_constants, keeper_strings
from smskeeper import analytics
from smskeeper import time_utils

from common import date_util, weather_util, slack_logger

logger = get_task_logger(__name__)


# Returns true if:
# The remind timestamp ends in 0 or 30 minutes and its within 10 minutes of then
# The current time is after the remind timestamp but we're within 5 minutes
# Hidden is false
def shouldRemindNow(entry):
	# TODO: Remove this line. Leaving it in for now as a last defense against sending hidden reminders
	if entry.hidden:
		return False

	# Don't remind if we have already send one out
	if not entry.remind_to_be_sent:
		return False

	now = date_util.now(pytz.utc)

	# Don't remind if its too far in the past
	if entry.remind_timestamp < now - datetime.timedelta(minutes=5):
		return False

	# Don't remind if this has use_digest_time set (just shows up on digest)
	if entry.use_digest_time:
		return False

	# Don't send a reminder if this is during the digest time, since it'll be
	# included in that
	if entry.creator.isDigestTime(entry.remind_timestamp) and not entry.creator.product_id == keeper_constants.MEDICAL_PRODUCT_ID:
		return False

	# If we're recurring and we're after the end date
	if entry.remind_recur_end and entry.remind_timestamp > entry.remind_recur_end:
		return False

	if ((entry.remind_timestamp.minute == 0 or entry.remind_timestamp.minute == 30) and
				(entry.remind_timestamp - entry.updated).total_seconds() > 60 * 60):  # Don't do this if they set this less than an hour ago
		# If we're within 10 minutes, so alarm goes off at 9:50 if remind is at 10
		return (now + datetime.timedelta(minutes=10) > entry.remind_timestamp)
	else:
		return (now >= entry.remind_timestamp)


def updateEntryAfterProcessing(entry):
	entry.remind_last_notified = date_util.now(pytz.utc)
	entry.remind_to_be_sent = False
	entry.save()

	# Create a new reminder entry if this one is recurring
	# We don't re-use the old one so people can 'done' it or 'snooze'
	if entry.remind_recur != keeper_constants.RECUR_DEFAULT and entry.remind_recur != keeper_constants.RECUR_ONE_TIME:
		if entry.remind_recur == keeper_constants.RECUR_WEEKLY:
			newRemindTimestamp = entry.remind_timestamp + datetime.timedelta(weeks=1)
		elif entry.remind_recur == keeper_constants.RECUR_DAILY:
			newRemindTimestamp = entry.remind_timestamp + datetime.timedelta(days=1)
		elif entry.remind_recur == keeper_constants.RECUR_MONTHLY:
			newRemindTimestamp = entry.remind_timestamp + relativedelta(months=1)
		elif entry.remind_recur == keeper_constants.RECUR_EVERY_2_DAYS:
			newRemindTimestamp = entry.remind_timestamp + datetime.timedelta(days=2)
		elif entry.remind_recur == keeper_constants.RECUR_EVERY_2_WEEKS:
			newRemindTimestamp = entry.remind_timestamp + datetime.timedelta(days=14)
		elif entry.remind_recur == keeper_constants.RECUR_WEEKDAYS:
			tzAwareNow = date_util.now(entry.creator.getTimezone())

			if tzAwareNow.weekday() >= 4:  # Friday, Sat or Sun
				newRemindTimestamp = entry.remind_timestamp + datetime.timedelta(days=6 - tzAwareNow.weekday() + 1)
			else:
				newRemindTimestamp = entry.remind_timestamp + datetime.timedelta(days=1)

		# If we don't have a remind end or if the new remind stamp is before the end, create a new entry
		if ((entry.remind_recur_end and newRemindTimestamp and newRemindTimestamp < entry.remind_recur_end or not entry.remind_recur_end)):
			newEntry = Entry(creator=entry.creator, label=entry.label, text=entry.text, orig_text=entry.orig_text, remind_recur=entry.remind_recur, remind_recur_end=entry.remind_recur_end, created_from_entry_id=entry.id)
			newEntry.remind_timestamp = newRemindTimestamp

			# Not copying over 'users', will need to do that for shared reminders
			newEntry.save()
			logger.info("User %s: Created new entry %s since its recurring for next time %s" % (newEntry.creator.id, newEntry.id, newEntry.remind_timestamp))

		# Change original entry to be one time.  So if its snoozed, it doesn't turn stay recurring
		entry.remind_recur = keeper_constants.RECUR_ONE_TIME
		entry.save()

	return entry


def processReminder(entry):
	isSharedReminder = (len(entry.users.all()) > 1)

	users = set(entry.users.all())
	users.add(entry.creator)

	for user in users:
		if user.state == keeper_constants.STATE_STOPPED:
			pass
		else:
			if isSharedReminder:
				# If they've never used the system before
				if user.id == entry.creator.id:
					otherUserNames = entry.getOtherUserNames(entry.creator)

					msg = keeper_strings.SHARED_REMINDER_SENT_CONFIRMATION_TEXT % (", ".join(otherUserNames))
				elif user.state == keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER:
					msg = keeper_strings.SHARED_REMINDER_TEXT_TO_UNACTIVATED_USER % (entry.creator.name, entry.creator.name, entry.text)
				else:
					msg = keeper_strings.SHARED_REMINDER_TEXT_TO_ACTIVATED_USER % (entry.creator.name, entry.text)
			else:
				msg = random.choice(keeper_strings.REMINDER_PHRASES) + " %s" % entry.text

			sms_util.sendMsg(user, msg, classification=keeper_constants.OUTGOING_REMINDER)
			analytics.logUserEvent(
				user,
				"Reminder Received",
				parametersDict={
					"Num Users": len(users),
					"Is Reminder Creator": user.id == entry.creator.id,
					"Reminder type": entry.remind_recur,
					"Manually updated": entry.manually_updated,
					"Manually checked": entry.manually_check,
					"Hours since created": time_utils.totalHoursAgo(entry.added),
					"Is default time": entry.use_digest_time
				}
			)

			updateEntryAfterProcessing(entry)

			# We only want to send tips right now to default things
			isDefault = entry.remind_recur == keeper_constants.RECUR_DEFAULT

			# Only do fancy things like snooze if they've actually gone through the tutorial
			if user.completed_tutorial:
				if user.done_count < keeper_constants.GOAL_DONE_COUNT and isDefault:
					if keeper_constants.isRealKeeperNumber(user.getKeeperNumber()):
						time.sleep(2)

					tip = tips.DONE_MINI_TIPS_LIST[random.randint(0, 2)]
					sms_util.sendMsg(user, tip.renderMini())
				elif tips.SNOOZE_TIP_ID not in tips.getSentTipIds(user) and isDefault:
					# Hack for tests.  Could get rid of by refactoring reminder stuff into own async and using
					# sms_util for sending list of msgs
					if keeper_constants.isRealKeeperNumber(user.getKeeperNumber()):
						time.sleep(2)

					tip = tips.tipWithId(tips.SNOOZE_TIP_ID)
					sms_util.sendMsg(user, tip.renderMini())
					tips.markTipSent(user, tip, isMini=True)

				# Now set to reminder sent, incase they send back done message
				user.setStateData(keeper_constants.LAST_ENTRIES_IDS_KEY, [entry.id])

	entry.save()


@app.task
def processAllReminders():
	entries = Entry.objects.filter(remind_timestamp__isnull=False, hidden=False)

	for entry in entries:
		if shouldRemindNow(entry):
			logger.info("Processing entry: %s for users %s" % (entry.id, entry.users.all()))
			processReminder(entry)


def getDigestMessageForUser(user, pendingEntries, weatherDataCache, userRequested, sweptEntries):
	now = date_util.now(pytz.utc)
	userNow = date_util.now(user.getTimezone())
	msg = ""

	if not userRequested:  # Include a header and weather if not user requested
		headerPhrase = random.choice(keeper_strings.REMINDER_DIGEST_HEADERS[userNow.weekday()])
		msg += u"%s\n" % (headerPhrase)

		if user.wxcode:
			weatherPhrase = weather_util.getWeatherPhraseForZip(user, user.wxcode, userNow, weatherDataCache)
			if weatherPhrase:
				msg += u"\n%s\n\n" % (weatherPhrase)

	if len(pendingEntries) == 0:
		if userRequested:
			msg += random.choice(keeper_strings.USER_REQUESTED_DIGEST_EMPTY)
		else:
			msg += random.choice(keeper_strings.REMINDER_DIGEST_EMPTY[userNow.weekday()]) + '\n'
	else:
		if userRequested:  # This shows all tasks so we don't mention today
			msg += keeper_strings.DIGEST_HEADER_USER_REQUESTED + "\n"
		else:
			msg += keeper_strings.DIGEST_HEADER_TODAY + "\n"

		for entry in pendingEntries:
			# If this is the digest and this reminder was timed to this day and time...then process it (mark it as sent)
			if not userRequested and user.isDigestTime(entry.remind_timestamp) and now.day == entry.remind_timestamp.day:
				updateEntryAfterProcessing(entry)

			# If this is a daily entry not set for digest time, then skip including the message
			if not userRequested and entry.remind_recur == keeper_constants.RECUR_DAILY and not user.isDigestTime(entry.remind_timestamp):
				continue

			msg += generateTaskStringForDigest(user, entry)

	if not userRequested and len(sweptEntries) > 0:
		msg += "\n" + keeper_strings.SWEEP_MESSAGE_TEXT % (user.getWebAppURL())
		for entry in sweptEntries:
			msg += generateTaskStringForDigest(user, entry)

	return msg


def generateTaskStringForDigest(user, entry):
	now = date_util.now(pytz.utc)
	msg = u"\U0001F538 " + entry.text
	if len(entry.users.all()) > 1:
		msg += " (%s)" % (", ".join(entry.getOtherUserNames(user)))

	if (entry.remind_timestamp > now + datetime.timedelta(minutes=1) and  # Need an extra minute since some 9am reminders are really 9:00:30
				not entry.use_digest_time):  # Don't show the time if it was a default time
		msg += " (%s)" % msg_util.naturalize(now, entry.remind_timestamp.astimezone(user.getTimezone()), True)
	msg += "\n"
	return msg


def cleanUpRecurringReminders(user, pendingEntries):
	now = date_util.now(user.getTimezone()) - datetime.timedelta(minutes=1)
	for entry in pendingEntries:
		# This is a recurring reminder that is in the past, hide it
		if entry.remind_recur != keeper_constants.RECUR_DEFAULT and entry.remind_timestamp < now:
			entry.hidden = True
			entry.save()

	return filter(lambda x: not x.hidden, pendingEntries)


def sendDigestForUser(user, pendingEntries, weatherDataCache, userRequested, overrideKeeperNumber=None, webFooter=False):
	keeperNumber = user.getKeeperNumber() if overrideKeeperNumber is None else overrideKeeperNumber

	# Not great at this low level but want to make sure it always gets called
	# This removes all
	pendingEntries = cleanUpRecurringReminders(user, pendingEntries)
	if not userRequested and date_util.now(user.getTimezone()).isoweekday() == keeper_constants.SWEEP_CLEANUP_WEEKDAY and user.sweeping_activated:
		pendingEntries, sweptEntries = sweepTasksForUser(user, pendingEntries)
	else:
		sweptEntries = []

	# We send the message here
	msg = getDigestMessageForUser(user, pendingEntries, weatherDataCache, userRequested, sweptEntries)
	if webFooter:
		msg += (keeper_strings.FETCH_DIGEST_FOOTER % user.getWebAppURL())

	sendToSlack = userRequested
	sms_util.sendMsg(user, msg, None, keeperNumber, classification=keeper_constants.OUTGOING_DIGEST, sendToSlack=sendToSlack)

	now = date_util.now(user.getTimezone())
	daysActive = (now - user.added).days
	tipSent = False

	analytics.logUserEvent(
		user,
		"Digest sent",
		parametersDict={
			"Num Entries": len(pendingEntries),
		}
	)

	if daysActive >= 2 and tips.isUserEligibleForMiniTip(user, tips.DIGEST_CHANGE_TIME_TIP_ID) and not userRequested:
		digestChangeTimeTip = tips.tipWithId(tips.DIGEST_CHANGE_TIME_TIP_ID)
		sms_util.sendDelayedMsg(user, digestChangeTimeTip.renderMini(), 5, classification=keeper_constants.OUTGOING_CHANGE_DIGEST_TIME)
		tips.markTipSent(user, digestChangeTimeTip, isMini=True)
		tipSent = True
	elif daysActive >= 7 and tips.isUserEligibleForMiniTip(user, tips.DIGEST_QUESTION_TIP_ID) and not userRequested:
		digestQuestionTip = tips.tipWithId(tips.DIGEST_QUESTION_TIP_ID)
		sms_util.sendDelayedMsg(user, digestQuestionTip.renderMini(), 5, classification=keeper_constants.OUTGOING_SURVEY)
		tips.markTipSent(user, digestQuestionTip, isMini=True)
		tipSent = True
	elif daysActive >= 9 and tips.isUserEligibleForMiniTip(user, tips.DIGEST_QUESTION_NPS_TIP_ID) and not userRequested:
		npsQuestionTip = tips.tipWithId(tips.DIGEST_QUESTION_NPS_TIP_ID)
		sms_util.sendDelayedMsg(user, npsQuestionTip.renderMini(), 5, classification=tips.DIGEST_QUESTION_NPS_TIP_ID)
		tips.markTipSent(user, npsQuestionTip, isMini=True)
		tipSent = True

	# Do post-message processing with pending reminders
	if len(pendingEntries) > 0:
		# Now set to reminder sent, incase they send back done message
		user.setStateData(keeper_constants.LAST_ENTRIES_IDS_KEY, [x.id for x in pendingEntries])

		if not tipSent:
			has3dayOldEntry = False

			for entry in pendingEntries:
				if entry.remind_timestamp < now - datetime.timedelta(days=3):
					has3dayOldEntry = True

			# Do mini tips for digest.
			# If they have a 3 day old entry, tell them to snooze
			# If they don't, but they havn't hit their "done" goal then show done
			if has3dayOldEntry and tips.DIGEST_SNOOZE_TIP_ID not in tips.getSentTipIds(user):
				digestTip = tips.tipWithId(tips.DIGEST_SNOOZE_TIP_ID)
				sms_util.sendDelayedMsg(user, digestTip.renderMini(), 5)
				tips.markTipSent(user, digestTip, isMini=True)
			elif user.done_count < keeper_constants.GOAL_DONE_COUNT:
				digestTip = tips.tipWithId(tips.DIGEST_DONE_TIP_ID)
				sms_util.sendDelayedMsg(user, digestTip.renderMini(), 5)


# For this user, sweep all the tasks older than age given and return them
def sweepTasksForUser(user, pendingEntries, age=keeper_constants.SWEEP_CUTOFF_TIME_FOR_OLD_TASKS_IN_DAYS):
	sweptEntries = []
	now = date_util.now(pytz.utc)

	for entry in pendingEntries:
		if entry.remind_recur == keeper_constants.RECUR_DEFAULT and entry.remind_last_notified and entry.remind_last_notified < now - datetime.timedelta(days=age):
			entry.state = keeper_constants.REMINDER_STATE_SWEPT
			entry.last_state_change = now
			entry.save()
			logger.info("Sweeping task %s for user %s" % (entry.id, user.id))
			sweptEntries.append(entry)

	for entry in sweptEntries:
		pendingEntries.remove(entry)

	return pendingEntries, sweptEntries


# Used to send daily digest to specific list of people. Written for when Twilio failed.
# IMPORTANT: THIS FUNCTION DOESN'T CHECK FOR DIGEST TIME (since it's meant to resend missed digests at a later time)
def processDailyDigestFromList(userIdList):
	weatherDataCache = dict()

	userList = User.objects.filter(id__in=userIdList)

	for user in userList:
		if user.state == keeper_constants.STATE_STOPPED or user.state == keeper_constants.STATE_SUSPENDED:
			continue

		if user.product_id == keeper_constants.MEDICAL_PRODUCT_ID:
			continue

		if not user.completed_tutorial:
			continue

		pendingEntries = user_util.pendingTodoEntries(user, includeAll=False)

		if len(pendingEntries) > 0:
			sendDigestForUser(user, pendingEntries, weatherDataCache, False)

		# No pending entries, make sure they have digest state to default and product id 1
		elif user.product_id >= keeper_constants.TODO_PRODUCT_ID and user.digest_state == keeper_constants.DIGEST_STATE_DEFAULT:
			sendDigestForUser(user, pendingEntries, weatherDataCache, False)


@app.task
def sendDigestForUserId(userId, overrideKeeperNumber=None):

	user = User.objects.get(id=userId)
	pendingEntries = user_util.pendingTodoEntries(user, includeAll=False)

	sendDigestForUser(user, pendingEntries, dict(), True, overrideKeeperNumber=overrideKeeperNumber)


# This method is different since we pass True for includeAll
@app.task
def sendAllRemindersForUserId(userId, overrideKeeperNumber=None):
	user = User.objects.get(id=userId)
	pendingEntries = user_util.pendingTodoEntries(user, includeAll=True)

	sendDigestForUser(user, pendingEntries, dict(), True, overrideKeeperNumber=overrideKeeperNumber, webFooter=True)


@app.task
def processDailyDigest(startAtId=None, minuteOverride=None):
	weatherDataCache = dict()
	usersSentTo = list()

	if startAtId:
		users = User.objects.filter(id__gt=startAtId)
	else:
		users = User.objects.all()

	for user in users:
		if user.state == keeper_constants.STATE_STOPPED or user.state == keeper_constants.STATE_SUSPENDED:
			continue

		if user.product_id == keeper_constants.MEDICAL_PRODUCT_ID:
			continue

		if not user.isDigestTime(date_util.now(pytz.utc), minuteOverride):
			continue

		if not user.completed_tutorial:
			continue

		if user.digest_state == keeper_constants.DIGEST_STATE_NEVER:
			continue

		pendingEntries = user_util.pendingTodoEntries(user, includeAll=False)

		sentDigest = False
		if len(pendingEntries) > 0:
			sendDigestForUser(user, pendingEntries, weatherDataCache, False)
			sentDigest = True

		# No pending entries, make sure they have digest state to default and product id 1
		elif user.product_id >= keeper_constants.TODO_PRODUCT_ID and user.digest_state == keeper_constants.DIGEST_STATE_DEFAULT:
			sendDigestForUser(user, pendingEntries, weatherDataCache, False)
			sentDigest = True

		if sentDigest:
			usersSentTo.append(user)

		if len(usersSentTo) > 20:
			keeperNumber = usersSentTo[0].getKeeperNumber()

			msg = "Digest sent to users: "

			for user in usersSentTo:
				msg += "%s " % user.id

			slack_logger.postString(msg, keeper_constants.SLACK_CHANNEL_FEED, keeperNumber)
			usersSentTo = list()


@app.task
def sendTips(overrideKeeperNumber=None):
	usersSentTo = list()

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

			usersSentTo.append(user)

		if len(usersSentTo) > 20:
			keeperNumber = overrideKeeperNumber
			if not keeperNumber:
				keeperNumber = usersSentTo[0].getKeeperNumber()

			msg = "Sent tip to users: "

			for user in usersSentTo:
				msg += "%s " % user.id

			slack_logger.postString(msg, keeper_constants.SLACK_CHANNEL_FEED, keeperNumber)
			usersSentTo = list()


def sendTipToUser(tip, user, keeperNumber):
	sms_util.sendMsg(user, tip.render(user), tip.mediaUrl, keeperNumber, sendToSlack=False)
	tips.markTipSent(user, tip)


def str_now_1():
	return str(datetime.now())


@app.task
def testCelery():
	logger.debug("Celery task ran.")


@app.task
def suspendInactiveUsers(doit=False, days=7):
	now = date_util.now(pytz.utc)
	cutoff = now - datetime.timedelta(days=days)

	users = User.objects.exclude(state=keeper_constants.STATE_SUSPENDED).exclude(state=keeper_constants.STATE_STOPPED)
	for user in users:
		lastMessageIn = Message.objects.filter(user=user, incoming=True).order_by("added").last()

		futureReminders = user_util.pendingTodoEntries(user, includeAll=True, after=now)
		if lastMessageIn and lastMessageIn.added < cutoff and len(futureReminders) == 0:
			logger.info("Putting user %s into suspended state because last message was %s" % (user.id, lastMessageIn.added))
			if doit:
				user.setState(keeper_constants.STATE_SUSPENDED, override=True)
				user.save()

import json
import random
import string
import datetime
import logging
import pytz

from django.conf import settings

from smskeeper import keeper_constants, keeper_strings

from smskeeper import sms_util
from smskeeper import analytics
from smskeeper import time_utils

from smskeeper.models import Entry, User

from common import date_util
from common import slack_logger
from common import phone_info_util

logger = logging.getLogger(__name__)


def createUser(phoneNumber, signupDataJson, keeperNumber, productId, introPhrase, isShare=False):
	if keeperNumber and productId is None:
		productId = keeper_constants.TODO_PRODUCT_ID
		for pId, number in settings.KEEPER_NUMBER_DICT.iteritems():
			if number == keeperNumber:
				productId = pId

	if productId == keeper_constants.REMINDER_PRODUCT_ID:
		productId = keeper_constants.TODO_PRODUCT_ID

	if productId is None:
		logger.error("Tried looking for a productId for number %s but couldn't find for incoming phone num %s" % (keeperNumber, phoneNumber))
		if keeperNumber == keeper_constants.SMSKEEPER_CLI_NUM:
			productId = keeper_constants.TODO_PRODUCT_ID
		else:
			return None

	user = User.objects.create(phone_number=phoneNumber, product_id=productId, signup_data_json=signupDataJson)

	if not user.invite_code:
		user.invite_code = ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(6))

	if not user.key:
		user.key = "P" + str(productId) + ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(6))

	# we need to set this before activating so we know whether to split tutorial messages etc
	user.carrier_info_json = phone_info_util.fetchCarrierInfoJsonForUser(user)

	if not isShare:
		tutorialState = activateUser(user, introPhrase, keeperNumber)
	else:
		user.setActivated(False)
		user.setState(keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER)
		tutorialState = None

	analytics.logUserEvent(
		user,
		"User Activated",
		{
			"Days Waiting": time_utils.daysAndHoursAgo(user.added)[0],
			"Tutorial": tutorialState,
			"Source": user.getSignupData('source'),
			"Is Share": isShare
		}
	)

	user.save()
	return user


# Activates user into tuorial state and sends the initial messages
def activateUser(user, introPhrase, keeperNumber):
	msgsToSend = list()

	productId = user.product_id

	if introPhrase:
		msgsToSend.append(introPhrase)

	if productId == keeper_constants.TODO_PRODUCT_ID:
		tutorialState = keeper_constants.STATE_TUTORIAL_TODO
		msgsToSend.extend([random.choice(x) for x in keeper_strings.INTRO_MESSAGES])
	elif productId == keeper_constants.MEDICAL_PRODUCT_ID:
		tutorialState = keeper_constants.STATE_TUTORIAL_MEDICAL
		msgsToSend.extend(keeper_strings.INTRO_MESSAGES_MEDICAL)
	elif productId == keeper_constants.STUDENT_PRODUCT_ID:
		tutorialState = keeper_constants.STATE_TUTORIAL_STUDENT
		msgsToSend.extend([random.choice(x) for x in keeper_strings.INTRO_MESSAGES])
	else:
		tutorialState = keeper_constants.STATE_TUTORIAL_TODO
		msgsToSend.extend([random.choice(x) for x in keeper_strings.INTRO_MESSAGES])

	user.setActivated(True, tutorialState=tutorialState)

	logger.debug("User %s: Just created user from keeperNumber %s to tutorial %s" % (user.id, keeperNumber, tutorialState))

	# Here we need to pass in the keeperNumber in the case of cli
	# Normally the overrideKeeper number is set in processing_util, but this code is run before that
	sms_util.sendMsgs(user, msgsToSend, keeperNumber=keeperNumber)
	return tutorialState


def shouldIncludeEntry(entry, includeAll):
	# Cutoff time is 23 hours ahead, could be changed later to be more tz aware
	localNow = date_util.now(entry.creator.getTimezone())
	# Cutoff time is midnight local time
	cutoffTime = (localNow + datetime.timedelta(days=1)).replace(hour=0, minute=0)

	if not entry.remind_timestamp:
		logger.warning("User %s: Found reminder without timestamp %s" % (entry.creator.id, entry.id))
		return False

	if not entry.hidden and (includeAll or entry.remind_timestamp < cutoffTime):
		return True
	return False


def pendingTodoEntries(user, includeAll=False, before=None, after=None):
	entries = Entry.fetchEntries(user, label="#reminders", hidden=False, orderByString="remind_timestamp", state=keeper_constants.REMINDER_STATE_NORMAL)

	results = list()
	for entry in entries:
		if shouldIncludeEntry(entry, includeAll):
			results.append(entry)

	if before:
		results = filter(lambda x: x.remind_timestamp < before, results)

	if after:
		results = filter(lambda x: x.remind_timestamp > after, results)

	return results


def setPaused(user, paused, keeperNumber, reason):
	user.paused = paused
	infoText = "User %s: " % (user.id)
	if (paused):
		user.last_paused_timestamp = date_util.now(pytz.utc)
		infoText += "paused, %s" % reason
	else:
		infoText += "unpaused, %s" % reason

	logger.info(infoText)
	user.save()

	slack_logger.postManualAlert(user, infoText, keeperNumber, keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)

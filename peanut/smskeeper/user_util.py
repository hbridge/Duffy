import json
import random
import string
import datetime
import logging

from django.conf import settings

from smskeeper import keeper_constants

from smskeeper import sms_util
from smskeeper import analytics
from smskeeper import time_utils
from smskeeper.whatsapp import whatsapp_util

from smskeeper.models import Entry, User

from common import date_util

logger = logging.getLogger(__name__)


def createUser(phoneNumber, signupDataJson, keeperNumber, productId=None):
	if keeperNumber and productId is None:
		productId = keeper_constants.TODO_PRODUCT_ID

		if whatsapp_util.isWhatsappNumber(keeperNumber):
			productId = keeper_constants.WHATSAPP_TODO_PRODUCT_ID

		if productId is None:
			logger.error("Tried looking for a productId for number %s but couldn't find for incoming phone num %s" % (keeperNumber, phoneNumber))
			if keeperNumber == keeper_constants.SMSKEEPER_CLI_NUM:
				productId = keeper_constants.TODO_PRODUCT_ID
			else:
				return None

	user = User.objects.create(phone_number=phoneNumber, product_id=productId, signup_data_json=signupDataJson)
	return user


# Options for tutorial state are:
# keeper_constants.STATE_TUTORIAL_REMIND and keeper_constants.STATE_TUTORIAL_LIST
def activate(userToActivate, introPhrase, tutorialState, keeperNumber):
	if not tutorialState:
		tutorialState = keeper_constants.STATE_TUTORIAL_TODO

	if userToActivate.product_id == keeper_constants.REMINDER_PRODUCT_ID:
		tutorialState = keeper_constants.STATE_TUTORIAL_TODO

	userToActivate.setActivated(True, tutorialState=tutorialState)

	if not userToActivate.invite_code:
		userToActivate.invite_code = ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(6))
		userToActivate.save()

	if not userToActivate.key:
		userToActivate.key = "K" + ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(6))
		userToActivate.save()

	msgsToSend = list()

	if introPhrase:
		msgsToSend.append(introPhrase)

	# --- For Paid experiment ---
	paid = ""
	if userToActivate.signup_data_json:
		signupData = json.loads(userToActivate.signup_data_json)
		if "paid" in signupData:
			paid = signupData["paid"]

	if "1" in paid:
		msgsToSend.extend(keeper_constants.INTRO_MESSAGES_PAID)
	else:
		# --- end Paid experiment code --
		msgsToSend.extend(keeper_constants.INTRO_MESSAGES)

	logger.debug("User %s: Just activated user to tutorial %s and keeperNumber %s" % (userToActivate.id, tutorialState, keeperNumber))

	sms_util.sendMsgs(userToActivate, msgsToSend, keeperNumber)

	analytics.logUserEvent(
		userToActivate,
		"User Activated",
		{
			"Days Waiting": time_utils.daysAndHoursAgo(userToActivate.added)[0],
			"Tutorial": tutorialState,
			"Source": userToActivate.getSignupData('source')
		}
	)


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
	entries = Entry.objects.filter(creator=user, label="#reminders", hidden=False)

	results = list()
	for entry in entries:
		if shouldIncludeEntry(entry, includeAll):
			results.append(entry)

	results = sorted(results, key=lambda x: x.remind_timestamp)

	if before:
		results = filter(lambda x: x.remind_timestamp < before, results)

	if after:
		results = filter(lambda x: x.remind_timestamp > after, results)

	return results

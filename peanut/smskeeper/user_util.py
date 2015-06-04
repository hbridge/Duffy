import json
import random
import string
import datetime

from smskeeper import keeper_constants

from smskeeper import sms_util
from smskeeper import analytics
from smskeeper import time_utils

from smskeeper.models import Entry


# Options for tutorial state are:
# keeper_constants.STATE_TUTORIAL_REMIND and keeper_constants.STATE_TUTORIAL_LIST
def activate(userToActivate, introPhrase, tutorialState, keeperNumber):
	if not tutorialState:
		tutorialState = keeper_constants.STATE_TUTORIAL_REMIND

	userToActivate.setActivated(True, tutorialState=tutorialState)

	if not userToActivate.invite_code:
		userToActivate.invite_code = ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(6))
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

	sms_util.sendMsgs(userToActivate, msgsToSend, keeperNumber)

	source = None
	if userToActivate.signup_data_json:
		signupData = json.loads(userToActivate.signup_data_json)
		if "source" in signupData:
			source = signupData["source"]

	analytics.logUserEvent(
		userToActivate,
		"User Activated",
		{
			"Days Waiting": time_utils.daysAndHoursAgo(userToActivate.added)[0],
			"Tutorial": tutorialState,
			"Source": source
		}
	)


def shouldIncludeEntry(entry):
	# Cutoff time is 23 hours ahead, could be changed later to be more tz aware
	localNow = datetime.datetime.now(entry.creator.getTimezone())
	# Cutoff time is midnight local time
	cutoffTime = (localNow + datetime.timedelta(days=1)).replace(hour=0, minute=0)

	if not entry.hidden and entry.remind_timestamp < cutoffTime:
		return True
	return False


def pendingTodoEntries(user, entries=None):
	if user.product_id < 1:
		return []

	if entries is None:
		entries = Entry.objects.filter(creator=user, label="#reminders", hidden=False)

	results = list()
	for entry in entries:
		if shouldIncludeEntry(entry):
			results.append(entry)

	return results

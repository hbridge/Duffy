import json

from smskeeper import keeper_constants

from smskeeper import sms_util
from smskeeper import analytics
from smskeeper import time_utils


# Options for tutorial state are:
# keeper_constants.STATE_TUTORIAL_REMIND and keeper_constants.STATE_TUTORIAL_LIST
def activate(userToActivate, introPhrase, tutorialState, keeperNumber):
	if not tutorialState:
		tutorialState = keeper_constants.STATE_TUTORIAL_REMIND

	userToActivate.setActivated(True, tutorialState=tutorialState)

	msgsToSend = list()

	if introPhrase:
		msgsToSend.append(introPhrase)

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

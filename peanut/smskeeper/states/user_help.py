from smskeeper import keeper_constants
from smskeeper import sms_util
from smskeeper import analytics

import logging
logger = logging.getLogger(__name__)

def process(user, msg, requestDict, keeperNumber):
	if "NumMedia" in requestDict:
		numMedia = int(requestDict["NumMedia"])
		if numMedia > 0:
			user.setState(keeper_constants.STATE_NORMAL)
			return False

	cleanedMsg = msg.lower()
	subject = None
	isExampleRequest = False

	processed = False
	if "list" in cleanedMsg:
		subject = keeper_constants.LISTS_HELP_SUBJECT
	elif "reminder" in cleanedMsg:
		subject = keeper_constants.REMINDERS_HELP_SUBJECT

	if "example" in cleanedMsg:
		isExampleRequest = True
		if subject is None:
			subject = user.getStateData("subject")

	analytics.logUserEvent(
		user,
		"Requested Help",
		{
			"Subject": subject,
			"Help Type": "Example" if isExampleRequest else "General"
		}
	)

	if subject in keeper_constants.HELP_SUBJECTS.keys():
		if isExampleRequest:
			sms_util.sendMsgs(
				user,
				["Sure! Here are a few examples:"] + keeper_constants.HELP_SUBJECTS[subject][keeper_constants.EXAMPLES_HELP_KEY],
				keeperNumber
			)
			processed = True
		else:
			sms_util.sendMsgs(
				user,
				keeper_constants.HELP_SUBJECTS[subject][keeper_constants.GENERAL_HELP_KEY] + ["Say 'examples' if you want more examples."],
				keeperNumber,
			)
			user.setStateData("subject", subject)
			processed = True

	if not processed:
		user.setState(keeper_constants.STATE_NORMAL)

	return processed

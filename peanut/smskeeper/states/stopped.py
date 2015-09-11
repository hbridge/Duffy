from smskeeper import keeper_constants, keeper_strings
from smskeeper import sms_util
from smskeeper import analytics
from smskeeper import time_utils


def process(user, msg, requestDict, keeperNumber):
	# We were already in this state
	# If we got the start message, then ignore
	if msg.lower() == "start":
		# Need to do this to by-pass user.setState protocols
		user.state = keeper_constants.STATE_NORMAL
		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		sms_util.sendMsg(user, keeper_strings.START_RESPONSE, None, keeperNumber)
		analytics.logUserEvent(
			user,
			"Stop/Start",
			{
				"Action": "Start",
				"Hours Paused": time_utils.totalHoursAgo(user.last_state_change),
			}
		)
		return True, keeper_constants.CLASS_STOP, dict()

	# Ignore other messages
	return True, keeper_constants.CLASS_NONE, dict()

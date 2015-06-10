from smskeeper import keeper_constants
from smskeeper import sms_util
from smskeeper import analytics
from smskeeper import time_utils


def process(user, msg, requestDict, keeperNumber):
	# We were already in this state
	# If we got the start message, then ignore
	if msg.lower() == "start":
		user.setState(keeper_constants.STATE_NORMAL)
		user.save()
		sms_util.sendMsg(user, u"\U0001F44B Welcome back!", None, keeperNumber)
		analytics.logUserEvent(
			user,
			"Stop/Start",
			{
				"Action": "Start",
				"Hours Paused": time_utils.totalHoursAgo(user.last_state_change),
			}
		)

	# Ignore other messages
	return True


# Hack, this kinda stands out where the processing_util calls this
def dealWithStop(user, msg, keeperNumber):
	sms_util.sendMsg(user, u"I won't txt you anymore \U0001F61E. If you didn't mean to do this, just type 'start'", None, keeperNumber)
	analytics.logUserEvent(
		user,
		"Stop/Start",
		{"Action": "Stop"}
	)
	if user.state != keeper_constants.STATE_STOPPED:
		user.setState(keeper_constants.STATE_STOPPED, saveCurrent=True, override=True)
		user.save()

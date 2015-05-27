from smskeeper import keeper_constants
from smskeeper import sms_util


def process(user, msg, requestDict, keeperNumber):
	# did we just come into this state
	if not user.getStateData('step'):
		sms_util.sendMsg(user, "You have unsubscribed from Keeper. If you didn't mean to do this, just type 'start'", None, keeperNumber)
		user.setStateData('step', 1)
		user.save()
		return True
	else:
		# We were already in this state
		# If we got the start message, then ignore
		if msg.lower() == "start":
			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
			sms_util.sendMsg(user, "Got it, welcome back", None, keeperNumber)

		# Ignore other messages
		return True

from smskeeper import keeper_constants


def process(user, msg, requestDict, keeperNumber):
	# If we get anything from them, start up again
	user.setState(keeper_constants.STATE_NORMAL)
	user.save()

	# If we got the start message, then ignore
	if msg.lower() == "start":
		return True
	# Otherwise, send through processing
	return False

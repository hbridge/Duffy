from smskeeper import keeper_constants


def process(user, msg, requestDict, keeperNumber):
	# We got a message from them, so set back to normal state and process per usual
	user.setState(keeper_constants.STATE_NORMAL)
	user.save()

	return False, None

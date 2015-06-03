import json
import logging

from smskeeper import keeper_constants
from smskeeper import analytics

from smskeeper.states import not_activated, not_activated_from_reminder, tutorial_list, tutorial_reminders, remind, normal, unresolved_handles, unknown_command, implicit_label, stopped, user_help
from smskeeper import msg_util

from smskeeper.models import User, Message
from common import slack_logger

logger = logging.getLogger(__name__)


def processMessage(phoneNumber, msg, requestDict, keeperNumber):
	try:
		user = User.objects.get(phone_number=phoneNumber)
	except User.DoesNotExist:
		try:
			user = User.objects.create(phone_number=phoneNumber)
		except Exception as e:
			logger.error("Got Exception in user creation: %s" % e)
	except Exception as e:
		logger.error("Got Exception in user creation: %s" % e)
	finally:
		# This is true if this is from a manual entry off the history page
		manual = "Manual" in requestDict
		messageObject = Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True, manual=manual)
		slack_logger.postMessage(messageObject, keeper_constants.SLACK_CHANNEL_FEED)

	# convert message to unicode
	if type(msg) == str:
		msg = msg.decode('utf-8')
	msg = msg.strip()

	# Grab just the first line, so we ignore signatures
	msg = msg.split('\n')[0]

	# Always look for a stop command first and deal with that
	if msg_util.isStopCommand(msg):
		user.setState(keeper_constants.STATE_STOPPED, saveCurrent=True)
		user.save()
		logger.debug("I think '%s' is a stop command, setting state to %s for user %s" % (msg, user.state, user.id))

	if not user.paused:
		processed = False
		count = 0
		while not processed and count < 10:
			stateModule = stateCallbacks[user.state]
			logger.debug("About to process state %s with state_data %s for msg '%s' from user %s" % (user.state, user.state_data, msg, user.id))
			processed = stateModule.process(user, msg, requestDict, keeperNumber)
			if processed is None:
				raise TypeError("modules must return True or False for processed")
			count += 1

		if count == 10:
			logger.error("Hit endless loop for msg %s" % msg)

	analytics.logUserEvent(
		user,
		"Incoming",
		None
	)


stateCallbacks = {
	keeper_constants.STATE_NOT_ACTIVATED: not_activated,
	keeper_constants.STATE_TUTORIAL_LIST: tutorial_list,
	keeper_constants.STATE_TUTORIAL_REMIND: tutorial_reminders,
	keeper_constants.STATE_NORMAL: normal,
	keeper_constants.STATE_REMIND: remind,
	keeper_constants.STATE_UNRESOLVED_HANDLES: unresolved_handles,
	keeper_constants.STATE_UNKNOWN_COMMAND: unknown_command,
	keeper_constants.STATE_IMPLICIT_LABEL: implicit_label,
	keeper_constants.STATE_STOPPED: stopped,
	keeper_constants.STATE_HELP: user_help,
	keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER: not_activated_from_reminder,
}

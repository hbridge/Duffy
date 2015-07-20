import json
import logging
import pytz
from datetime import timedelta

from smskeeper import keeper_constants
from smskeeper import analytics

from smskeeper.states import not_activated, not_activated_from_reminder, tutorial_list, tutorial_reminders, remind, reminder_sent, normal, unresolved_handles, unknown_command, implicit_label, stopped, user_help, tutorial_todo, suspended
from smskeeper import msg_util, user_util

from smskeeper.models import User, Message
from common import slack_logger, date_util
from smskeeper.engine import Engine

logger = logging.getLogger(__name__)


def getOrCreateUserFromPhoneNumber(phoneNumber, keeperNumber):
	# normalize the phone number
	normalized = phoneNumber.replace(keeper_constants.WHATSAPP_NUMBER_SUFFIX, "")
	if not normalized[0] == '+':
		normalized = "+%s" % normalized
	try:
		user = User.objects.get(phone_number=normalized)
		isNewUser = False
	except User.DoesNotExist:
		user = user_util.createUser(normalized, {}, keeperNumber, None)
		isNewUser = True
	return user, isNewUser


def processMessage(phoneNumber, msg, requestDict, keeperNumber):
	user, isNewUser = getOrCreateUserFromPhoneNumber(phoneNumber, keeperNumber)

	# This is true if this is from a manual entry off the history page
	manual = "Manual" in requestDict
	if not manual and isDuplicateMsg(user, msg):
		logger.info("User %s: Ignoring duplicate message: %s" % (user.id, msg))
		# TODO figure out better logic so we aren't repeating this statement
		messageObject = Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True, manual=manual)
		return False

	messageObject = Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True, manual=manual)
	slack_logger.postMessage(messageObject, keeper_constants.SLACK_CHANNEL_FEED)

	if user.getKeeperNumber() != keeperNumber and keeper_constants.isRealKeeperNumber(keeperNumber):
		logger.error("User %s: Recieved message '%s' to number %s but user should be sending to %s" % (user.id, msg, keeperNumber, user.getKeeperNumber()))
		keeperNumber = user.getKeeperNumber()

	processed = False
	# convert message to unicode
	if type(msg) == str:
		msg = msg.decode('utf-8')
	msg = msg.strip()
	# Grab just the first line, so we ignore signatures
	msg = msg.split('\n')[0]

	logger.info("User %s: START with '%s'. State %s with state_data %s" % (user.id, msg, user.state, user.state_data))

	classification = None
	if not user.paused:
		# If we're not a new user, process basic stuff. New users skip this so we don't filter on nicetys
		if not isNewUser:
			keeperEngine = Engine()
			processed, classification = keeperEngine.process(user, msg, requestDict, keeperNumber)
		if processed:
			messageObject.auto_classification = classification
			messageObject.save()
		else:
			count = 0
			while not processed and count < 10:
				stateModule = stateCallbacks[user.state]
				logger.debug("User %s: About to process '%s' with state: %s and state_data: %s" % (user.id, msg, user.state, user.state_data))
				processed, classification = stateModule.process(user, msg, requestDict, keeperNumber)
				if processed is None:
					raise TypeError("modules must return True or False for processed")
				count += 1

				if processed:
					user.last_state = user.state
					user.save()
					messageObject.auto_classification = classification
					messageObject.save()
					logger.debug("User %s: DONE with '%s' with state: %s  and state_data: %s" % (user.id, msg, user.state, user.state_data))

			if count == 10:
				logger.error("User %s: Hit endless loop for msg '%s'" % (user.id, msg))
	else:
		logger.debug("User %s: not processing '%s' because they are paused" % (user.id, msg))

	analytics.logUserEvent(
		user,
		"Incoming",
		{"Is Stop": classification != keeper_constants.CLASS_STOP}
	)


stateCallbacks = {
	keeper_constants.STATE_NOT_ACTIVATED: not_activated,
	keeper_constants.STATE_TUTORIAL_LIST: tutorial_list,
	keeper_constants.STATE_TUTORIAL_REMIND: tutorial_reminders,
	keeper_constants.STATE_NORMAL: normal,
	keeper_constants.STATE_REMIND: remind,
	keeper_constants.STATE_REMINDER_SENT: reminder_sent,
	keeper_constants.STATE_UNRESOLVED_HANDLES: unresolved_handles,
	keeper_constants.STATE_UNKNOWN_COMMAND: unknown_command,
	keeper_constants.STATE_IMPLICIT_LABEL: implicit_label,
	keeper_constants.STATE_STOPPED: stopped,
	keeper_constants.STATE_SUSPENDED: suspended,
	keeper_constants.STATE_HELP: user_help,
	keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER: not_activated_from_reminder,
	keeper_constants.STATE_TUTORIAL_TODO: tutorial_todo,
}

# Checks for duplicate message
def isDuplicateMsg(user, msg):
	incomingMsg = Message.objects.filter(user=user, incoming=True, added__gt=date_util.now(pytz.utc)-timedelta(minutes=2)).order_by('-added')
	if len(incomingMsg) > 0:
		if incomingMsg[0].msg_json:
			content = json.loads(incomingMsg[0].msg_json)
			if 'Body' in content and content['Body'] == msg:
				return True

	return False

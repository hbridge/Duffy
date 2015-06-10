import json
import logging
import pytz
from datetime import timedelta

from smskeeper import keeper_constants
from smskeeper import analytics

from smskeeper.states import not_activated, not_activated_from_reminder, tutorial_list, tutorial_reminders, remind, reminder_sent, normal, unresolved_handles, unknown_command, implicit_label, stopped, user_help, tutorial_todo
from smskeeper import msg_util, actions, niceties, sms_util

from smskeeper.models import User, Message
from common import slack_logger, date_util

logger = logging.getLogger(__name__)


# Process basic and important things like STOP, "hey there", "thanks", etc
# Need hacks for if those commands might be used later on though
def processBasicMessages(user, msg, requestDict, keeperNumber):
	# Always look for a stop command first and deal with that
	if msg_util.isStopCommand(msg):
		logger.debug("User %s: I think '%s' is a stop command, setting state to %s" % (user.id, msg, user.state))
		sms_util.sendMsg(user, u"I won't txt you anymore \U0001F61E. If you didn't mean to do this, just type 'start'", None, keeperNumber)
		analytics.logUserEvent(
			user,
			"Stop/Start",
			{"Action": "Stop"}
		)
		user.setState(keeper_constants.STATE_STOPPED, saveCurrent=True, override=True)
		user.save()
		return True
	elif niceties.getNicety(msg):
		# Hack(Derek): Make if its a nicety that also could be considered done...let that through
		if msg_util.isDoneCommand(msg) and user.product_id == 1:
			logger.debug("User %s: I think '%s' is a nicety but its also a done command, booting out" % (user.id, msg))
			return False
		nicety = niceties.getNicety(msg)
		logger.debug("User %s: I think '%s' is a nicety" % (user.id, msg))
		actions.nicety(user, nicety, requestDict, keeperNumber)
		return True
	elif msg_util.isHelpCommand(msg) and user.completed_tutorial:
		logger.debug("For user %s I think '%s' is a help command" % (user.id, msg))
		actions.help(user, msg, keeperNumber)
		return True
	elif msg_util.isQuestion(msg):
		logger.debug("User %s: I think '%s' is a question" % (user.id, msg))
		actions.unknown(user, msg, keeperNumber)
		return True
	elif msg_util.isSetTipFrequencyCommand(msg):
		logger.debug("For user %s I think '%s' is a set tip frequency command" % (user.id, msg))
		actions.setTipFrequency(user, msg, keeperNumber)
		return True
	elif msg_util.nameInSetName(msg):
		logger.debug("User %s: I think '%s' is a set name command" % (user.id, msg))
		actions.setName(user, msg, keeperNumber)
		return True
	elif msg_util.isSetZipcodeCommand(msg):
		logger.debug("User %s: I think '%s' is a set zip command" % (user.id, msg))
		actions.setZipcode(user, msg, keeperNumber)
		return True
	return False


def processMessage(phoneNumber, msg, requestDict, keeperNumber):
	try:
		user = User.objects.get(phone_number=phoneNumber)
		newUser = False
	except User.DoesNotExist:
		try:
			user = User.objects.create(phone_number=phoneNumber)
			newUser = True
		except Exception as e:
			logger.error("Got Exception in user creation: %s" % e)
	except Exception as e:
		logger.error("Got Exception in user creation: %s" % e)
	finally:
		# This is true if this is from a manual entry off the history page
		manual = "Manual" in requestDict
		if isDuplicateMsg(user, msg):
			logger.debug("Ignore duplicate message from user %s: %s"%(user.id, msg))
			# TODO figure out better logic so we aren't repeating this statement
			messageObject = Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True, manual=manual)
			return False
		messageObject = Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True, manual=manual)
		slack_logger.postMessage(messageObject, keeper_constants.SLACK_CHANNEL_FEED)



	processed = False
	# convert message to unicode
	if type(msg) == str:
		msg = msg.decode('utf-8')
	msg = msg.strip()
	# Grab just the first line, so we ignore signatures
	msg = msg.split('\n')[0]

	logger.debug("User %s: Starting processing of '%s'. State %s with state_data %s" % (user.id, msg, user.state, user.state_data))

	# If we're not a new user, process basic stuff. New users skip this so we don't filter on nicetys
	if not newUser:
		processed = processBasicMessages(user, msg, requestDict, keeperNumber)

	if not user.paused and not processed:
		count = 0
		while not processed and count < 10:
			stateModule = stateCallbacks[user.state]
			logger.debug("User %s: About to process '%s' with state: %s and state_data: %s" % (user.id, msg, user.state, user.state_data))
			processed = stateModule.process(user, msg, requestDict, keeperNumber)
			if processed is None:
				raise TypeError("modules must return True or False for processed")
			count += 1

			if processed:
				logger.debug("User %s: Done processing '%s' with state: %s  and state_data: %s" % (user.id, msg, user.state, user.state_data))

		if count == 10:
			logger.error("User %s: Hit endless loop for msg %s" % (user.id, msg))
	else:
		logger.debug("User %s: not processing '%s' because paused: %s  processed: %s" % (user.id, msg, user.paused, processed))

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
	keeper_constants.STATE_REMINDER_SENT: reminder_sent,
	keeper_constants.STATE_UNRESOLVED_HANDLES: unresolved_handles,
	keeper_constants.STATE_UNKNOWN_COMMAND: unknown_command,
	keeper_constants.STATE_IMPLICIT_LABEL: implicit_label,
	keeper_constants.STATE_STOPPED: stopped,
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

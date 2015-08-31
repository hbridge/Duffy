import json
import logging
import pytz
from datetime import timedelta

from smskeeper import keeper_constants
from smskeeper import analytics

from smskeeper.states import stopped, tutorial_todo, tutorial_medical, tutorial_student, suspended, not_activated_from_reminder
from smskeeper import actions, user_util, sms_util, helper_util
from smskeeper.chunk import Chunk

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
		created = False
	except User.DoesNotExist:
		user = user_util.createUser(normalized, {}, keeperNumber, None, None)
		created = True
	return user, created


# This processes the message where it removes the sig if it exists and splits up lines
# If this is the first msg in, then we look at anything after the first line and assume thats the sig
def processSigAndSplitLines(user, msg):
	msg = msg.strip()

	if user.signature_num_lines is None:
		# Get the first msg and see how many lines it is. Do this to support legacy users
		# This assumes a sig always shows up and will be on seperate lines and will be at the first msg
		firstMessage = Message.objects.filter(user=user, incoming=True).first()
		body = json.loads(firstMessage.msg_json)["Body"]
		user.signature_num_lines = len(body.split('\n')) - 1
		user.save()
		logger.info("User %s: Setting signature_num_lines to %s" % (user.id, user.signature_num_lines))

	# Grab just the first line, so we ignore signatures
	lines = msg.split('\n')

	if user.signature_num_lines == 0:
		return lines
	elif user.signature_num_lines == len(lines) - 1:
		return [lines[0]]
	elif user.signature_num_lines >= len(lines):
		# Edgecase if for some reason the sig isn't there
		return lines
	else:
		return lines[:len(lines) - user.signature_num_lines]


def processWithStateMachine(user, msgs, messageObject, requestDict, keeperNumber):
	# Stop, and tutorial states
	count = 0
	processed = False
	while not processed and count < 10:
		# For now, assume all state stuff uses one line
		# HACKY Should remove later
		msg = msgs[0]

		if user.state not in stateCallbacks:
			return False

		stateModule = stateCallbacks[user.state]

		logger.debug("User %s: About to process '%s' with state: %s and state_data: %s" % (user.id, msg, user.state, user.state_data))
		processed, classification, actionScores = stateModule.process(user, msg, requestDict, keeperNumber)

		if processed is None:
			raise TypeError("modules must return True or False for processed")

		if processed:
			user.last_state = user.state
			user.save()
			messageObject.auto_classification = classification
			messageObject.classification_scores_json = json.dumps(actionScores)
			messageObject.save()
			logger.debug("User %s: DONE with '%s' with state: %s  and state_data: %s" % (user.id, msg, user.state, user.state_data))

		if not processed:
			actions.unknown(user, msg, user.getKeeperNumber())

		count += 1
		if count == 10:
			logger.error("User %s: Hit endless loop for msg '%s'" % (user.id, msg))
	return True


def processWithEngine(user, msgs, messageObject):
	keeperEngine = Engine(Engine.DEFAULT, 0.0)
	multichunk = len(msgs) > 1

	if multichunk:
		logger.info("User %s:  Got %s lines in a single message" % (user.id, len(msgs)))

		timingCount = 0
		for msg in msgs:
			chunk = Chunk(msg)
			if chunk.getNattyResult(user):
				timingCount += 1

		# This makes sure we don't send anything to the user
		user.overrideKeeperNumber = "ignore"

		allProcessed = True
		lineCount = 0
		for msg in msgs:
			chunk = Chunk(msg, True, lineCount)
			chunkProcessed, classification, actionScores = keeperEngine.process(user, chunk)

			if not chunkProcessed:
				allProcessed = False
			lineCount += 1

		# Make sure we can send messages again
		user.overrideKeeperNumber = None

		# Hack for now, deal with printing out responses to multi-line messages
		if allProcessed:
			sms_util.sendMsg(user, "%s" % helper_util.randomAcknowledgement())
		else:
			actions.unknown(user, '\n'.join(msgs), user.getKeeperNumber())

		# We don't record the classification on the message since it was multi-line
	else:
		chunk = Chunk(msgs[0])
		processed, classification, actionScores = keeperEngine.process(
			user,
			chunk,
			overrideClassification=messageObject.classification
		)

		messageObject.auto_classification = classification
		messageObject.classification_scores_json = json.dumps(actionScores)
		messageObject.save()

		if not processed:
			actions.unknown(user, '\n'.join(msgs), user.getKeeperNumber())


def processMessage(phoneNumber, msg, requestDict, keeperNumber):
	user, created = getOrCreateUserFromPhoneNumber(phoneNumber, keeperNumber)

	# This is true if this is from a manual entry off the history page
	manual = "Manual" in requestDict

	# Deal with Dup messages (same thing sent in short amount of time)
	if not manual and isDuplicateMsg(user, msg):
		logger.info("User %s: Ignoring duplicate message: %s" % (user.id, msg))
		# TODO figure out better logic so we aren't repeating this statement
		messageObject = Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True, manual=manual)
		return False

	# Deal with keeper number stuff...if its cli or test, we set overrideKeeperNumber
	# which is looked at in sms_util
	if user.getKeeperNumber() != keeperNumber and keeper_constants.isRealKeeperNumber(keeperNumber):
		logger.error("User %s: Recieved message '%s' to number %s but user should be sending to %s" % (user.id, msg, keeperNumber, user.getKeeperNumber()))
		keeperNumber = user.getKeeperNumber()
	elif not keeper_constants.isRealKeeperNumber(keeperNumber):
		user.overrideKeeperNumber = keeperNumber

	# convert message to unicode
	if type(msg) == str:
		msg = msg.decode('utf-8')

	# Create Message object and post to slack
	# there may be an override message classification, if so create the message with it
	classification = requestDict.get("OverrideClass", None)
	messageObject = Message.objects.create(
		user=user,
		msg_json=json.dumps(requestDict),
		incoming=True,
		manual=manual,
		classification=classification
	)
	slack_logger.postMessage(messageObject, keeper_constants.SLACK_CHANNEL_FEED)

	if not user.paused and not created:
		logger.info("User %s: START with '%s'. State %s with state_data %s" % (user.id, msg, user.state, user.state_data))

		# Look at multiline messages, split up and deal with signatures
		msgs = processSigAndSplitLines(user, msg)

		processed = False
		if user.state in stateCallbacks:
			processed = processWithStateMachine(user, msgs, messageObject, requestDict, keeperNumber)

		# We might have changed state to NORMAL and it didn't process...so now use engine
		if not processed:
			processWithEngine(user, msgs, messageObject)
	else:
		if user.paused:
			logger.debug("User %s: not processing '%s' because they are paused" % (user.id, msg))
		elif created:
			logger.debug("User %s: not processing '%s' because they were just created...so msgs should have been sent" % (user.id, msg))

	analytics.logUserEvent(
		user,
		"Incoming",
		{"Is Stop": classification == keeper_constants.CLASS_STOP}
	)


stateCallbacks = {
	keeper_constants.STATE_TUTORIAL_TODO: tutorial_todo,
	keeper_constants.STATE_TUTORIAL_MEDICAL: tutorial_medical,
	keeper_constants.STATE_TUTORIAL_STUDENT: tutorial_student,
	keeper_constants.STATE_STOPPED: stopped,
	keeper_constants.STATE_SUSPENDED: suspended,
	keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER: not_activated_from_reminder,
}

# Checks for duplicate message
def isDuplicateMsg(user, msg):
	incomingMsg = Message.objects.filter(user=user, incoming=True, added__gt=date_util.now(pytz.utc) - timedelta(minutes=2)).order_by('-added')
	if len(incomingMsg) > 0:
		if incomingMsg[0].msg_json:
			content = json.loads(incomingMsg[0].msg_json)
			if 'Body' in content and content['Body'] == msg:
				return True

	return False

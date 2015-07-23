import time
import pytz
import logging
import datetime
import string

from smskeeper import sms_util
from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper import analytics
from smskeeper.models import Message

from smskeeper.engine import Engine

from common import date_util

logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	step = user.getStateData(keeper_constants.TUTORIAL_STEP_KEY)

	if step:
		step = int(step)
	else:
		step = 0

	analytics.logUserEvent(
		user,
		"Reached Tutorial Step",
		{
			"Tutorial": keeper_constants.STATE_TUTORIAL_TODO,
			"Step": step
		}
	)

	keeperEngine = Engine(Engine.TUTORIAL_BASIC, 0.5)
	processed, classification = keeperEngine.process(user, msg)

	if processed:
		return True, classification

	classification = None
	# Tutorial stuff
	if step == 0:
		# First see if they did a phrase like "my name is Billy"
		nameFromPhrase = msg_util.nameInSetName(msg, tutorial=True)

		if nameFromPhrase:
			user.name = nameFromPhrase
		else:
			msg = msg_util.removeNoOpWords(msg)

			# If there's more than two words, then reject
			if len(msg.split(' ')) > 2:
				sms_util.sendMsg(user, u"We'll get to that, but first what's your name?", None, keeperNumber)
				return True, keeper_constants.CLASS_NONE
			else:
				user.name = msg.strip(string.punctuation)

		user.save()

		if user.product_id == keeper_constants.WHATSAPP_TODO_PRODUCT_ID:
			postalCodeMessage = u"What's your postal/zip code? It'll help me remind you of things at the right time \U0001F553"
		else:
			postalCodeMessage = u"What's your zipcode? It'll help me remind you of things at the right time \U0001F553"

		sms_util.sendMsgs(
			user,
			[
				u"Great, nice to meet you %s! \U0001F44B" % user.getFirstName(),
				postalCodeMessage
			],
			keeperNumber
		)
		user.setStateData(keeper_constants.TUTORIAL_STEP_KEY, 1)
	elif step == 1:
		postalCode = msg_util.getPostalCode(msg)

		if postalCode:
			timezone, wxcode = msg_util.dataForPostalCode(postalCode)
			if timezone is None:
				response = "Sorry, I don't know that zipcode. Could you check that?"
				sms_util.sendMsg(user, response, None, keeperNumber)
				return True, keeper_constants.CLASS_NONE
			else:
				user.postal_code = postalCode
				user.timezone = timezone
				user.wxcode = wxcode
		else:
			logger.debug("postalCodes were none for: %s" % msg)
			lastMessageOut = Message.objects.filter(user=user, incoming=False).order_by("added").last()
			cutoff = date_util.now(pytz.utc) - datetime.timedelta(minutes=2)

			# If we last sent a message over 2 minutes ago, then send back I'm not sure
			if lastMessageOut.added < cutoff:
				response = "Got it, but first thing, what's your zipcode?"
				sms_util.sendMsg(user, response, None, keeperNumber)
				return True, keeper_constants.CLASS_NONE
			else:
				# else ignore
				return True, keeper_constants.CLASS_NONE

		sms_util.sendMsgs(user, [u"\U0001F44F Thanks! Let's add something you need to get done. \u2705", u"What's an item on your todo list right now? You can say things like 'Buy flip flops tomorrow' or 'Pick up Susie at 2:30 Friday'."], keeperNumber)

		user.setStateData(keeper_constants.TUTORIAL_STEP_KEY, 2)
	elif step == 2:
		postalCode = msg_util.getPostalCode(msg)

		if postalCode:
			# ignore
			return True, keeper_constants.CLASS_NONE

		keeperEngine = Engine(Engine.TUTORIAL_STEP_2, 0.5)
		processed, classification = keeperEngine.process(user, msg)

		# Hacky, if the action (createtodo) wanted the user to followup then it returns false
		# Then we'll come back here and once we get a followup, we'll post the last text
		if not processed:
			return True, keeper_constants.CLASS_NONE

		if keeper_constants.isRealKeeperNumber(keeperNumber):
			time.sleep(1)
		sms_util.sendMsgs(
			user,
			[
				u"It's that easy. Just txt me when things pop in your head and I'll track them for you. \U0001F60E What else do you need to do?",
			],
			keeperNumber)

		delayedTime = date_util.now(pytz.utc) + datetime.timedelta(minutes=20)
		sms_util.sendMsg(user, u"Oh and I'll also send your daily tasks in the morning \U0001F304 with weather forecast for that day \U0001F31E.", None, keeperNumber, eta=delayedTime)
		user.setTutorialComplete()
		classification = keeper_constants.CLASS_CREATE_TODO

		user.setState(keeper_constants.STATE_NORMAL)

		analytics.logUserEvent(
			user,
			"Completed Tutorial",
			{
				"Tutorial": keeper_constants.STATE_TUTORIAL_TODO
			}
		)
		analytics.setUserInfo(user)

	user.save()
	return True, classification

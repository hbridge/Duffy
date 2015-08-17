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
from smskeeper.chunk import Chunk

from smskeeper.engine import Engine

from common import date_util

logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	actionScores = dict()
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
	chunk = Chunk(msg)
	processed, classification, actionScores = keeperEngine.process(user, chunk)

	if processed:
		return True, classification, actionScores

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
				return True, keeper_constants.CLASS_NONE, actionScores
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
				return True, keeper_constants.CLASS_NONE, actionScores
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
				return True, keeper_constants.CLASS_NONE, actionScores
			else:
				# else ignore
				return True, keeper_constants.CLASS_NONE, actionScores

		sms_util.sendMsgs(user, [u"\U0001F44F Thanks! Let's add something you need to get done. \u2705", u"What's an item on your todo list right now? You can say things like 'Buy flip flops tomorrow' or 'Pick up Susie at 2:30 Friday'."], keeperNumber)

		user.setStateData(keeper_constants.TUTORIAL_STEP_KEY, 2)
	elif step == 2:
		postalCode = msg_util.getPostalCode(msg)

		if postalCode:
			logger.info("User %s: Ignoring '%s' since I think it has a postal code of '%s' in it and I have one already" % (user.id, msg, postalCode))
			# ignore
			return True, keeper_constants.CLASS_NONE, actionScores

		keeperEngine = Engine(Engine.TUTORIAL_STEP_2, 0.5)
		chunk = Chunk(msg)
		finishedWithCreate, classification, actionScores = keeperEngine.process(user, chunk)

		# Hacky, if the action (createtodo) wanted the user to followup then it returns false
		# Then we'll come back here and once we get a followup, we'll post the last text
		if not finishedWithCreate:
			return True, keeper_constants.CLASS_CREATE_TODO, actionScores

		if keeper_constants.isRealKeeperNumber(keeperNumber):
			time.sleep(1)
		sms_util.sendMsgs(
			user,
			[
				u"It's that easy. Just txt me when things pop in your head and I'll track them for you. \U0001F60E What else do you need to do?",
			],
			keeperNumber)

		delayedTime = date_util.now(pytz.utc) + datetime.timedelta(minutes=20)
		if user.product_id != keeper_constants.WHATSAPP_TODO_PRODUCT_ID:
			sms_util.sendMsg(user, u"Oh and here's my card. Tap it to save me to your address book. That way you'll know it's me when you get reminders :sunglasses:", keeper_constants.KEEPER_TODO_VCARD_URL, keeperNumber, eta=delayedTime)
			sms_util.sendMsg(user, u"ps: I'll also send you your tasks in the morning \U0001F304 with that day's weather \U0001F31E", None)
		else:
			sms_util.sendMsg(user, u"Oh and I'll also send you a morning txt \U0001F304 with with weather forecast \U0001F31E and daily tasks.", None, eta=delayedTime)
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
	return True, classification, actionScores

import time
import pytz
import logging
import datetime
import string

from smskeeper import sms_util
from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper import analytics
from smskeeper import chunk_features
from smskeeper.models import Message
from smskeeper.chunk import Chunk

from smskeeper.engine import Engine
from smskeeper.engine.v1_scorer import V1Scorer

from common import date_util

logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	actionsByScore = dict()
	step = user.getStateData(keeper_constants.TUTORIAL_STEP_KEY)

	if step:
		step = int(step)
	else:
		step = 0

	analytics.logUserEvent(
		user,
		"Reached Tutorial Step",
		{
			"Tutorial": keeper_constants.STATE_TUTORIAL_MEDICAL,
			"Step": step
		}
	)

	v1Scorer = V1Scorer(Engine.TUTORIAL_BASIC, 0.5)
	keeperEngine = Engine(Engine.TUTORIAL_BASIC, 0.5, tutorial=True)
	chunk = Chunk(msg)
	features = chunk_features.ChunkFeatures(chunk, user)

	actionsByScore = v1Scorer.score(user, chunk, features)
	bestActions = keeperEngine.getBestActions(user, chunk, actionsByScore, dict())

	processed, classification = keeperEngine.process(user, chunk, features, bestActions)

	if processed:
		return True, classification, actionsByScore

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
				return True, keeper_constants.CLASS_NONE, actionsByScore
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
			timezone, wxcode, tempFormat = msg_util.dataForPostalCode(postalCode)
			if timezone is None:
				response = "Sorry, I don't know that zipcode. Could you check that?"
				sms_util.sendMsg(user, response, None, keeperNumber)
				return True, keeper_constants.CLASS_NONE, actionsByScore
			else:
				user.postal_code = postalCode
				user.timezone = timezone
				user.wxcode = wxcode
				user.temp_format = tempFormat
		else:
			logger.debug("postalCodes were none for: %s" % msg)
			lastMessageOut = Message.objects.filter(user=user, incoming=False).order_by("added").last()
			cutoff = date_util.now(pytz.utc) - datetime.timedelta(minutes=2)

			# If we last sent a message over 2 minutes ago, then send back I'm not sure
			if lastMessageOut.added < cutoff:
				response = "Got it, but first thing, what's your zipcode?"
				sms_util.sendMsg(user, response, None, keeperNumber)
				return True, keeper_constants.CLASS_NONE, actionsByScore
			else:
				# else ignore
				return True, keeper_constants.CLASS_NONE, actionsByScore

		sms_util.sendMsgs(user, [u"\U0001F44F Thanks! Let's create a reminder \u2705  What medicine do you need and when?", u"You can say things like 'remind me to take vitamins at 10am everyday' or 'Remind me to take Ibuprofen 3 times a day'"], keeperNumber)

		user.setStateData(keeper_constants.TUTORIAL_STEP_KEY, 2)
	elif step == 2:
		postalCode = msg_util.getPostalCode(msg)

		if postalCode:
			logger.info("User %s: Ignoring '%s' since I think it has a postal code of '%s' in it and I have one already" % (user.id, msg, postalCode))
			# ignore
			return True, keeper_constants.CLASS_NONE, actionsByScore

		v1Scorer = V1Scorer(Engine.TUTORIAL_STEP_2, 0.5)
		keeperEngine = Engine(Engine.TUTORIAL_STEP_2, 0.5, tutorial=True)
		chunk = Chunk(msg)
		features = chunk_features.ChunkFeatures(chunk, user)

		actionsByScore = v1Scorer.score(user, chunk, features)
		bestActions = keeperEngine.getBestActions(user, chunk, actionsByScore, dict())

		finishedWithCreate, classification = keeperEngine.process(user, chunk, features, bestActions)

		# Hacky, if the action (createtodo) wanted the user to followup then it returns false
		# Then we'll come back here and once we get a followup, we'll post the last text
		if not finishedWithCreate:
			return True, keeper_constants.CLASS_CREATE_TODO, actionsByScore

		if keeper_constants.isRealKeeperNumber(keeperNumber):
			time.sleep(1)
		sms_util.sendMsgs(
			user,
			[
				u"It's that easy. I'll send you a reminder and you can tell me when you get it done.",
				u"Don't worry \U0001F60C, you can cancel anytime and I won't charge you if you cancel before 7-days.",
			],
			keeperNumber)

		#delayedTime = date_util.now(pytz.utc) + datetime.timedelta(minutes=20)
		#sms_util.sendMsg(user, u"Oh and I'll also send your daily tasks in the morning \U0001F304 with weather forecast for that day \U0001F31E.", None, keeperNumber, eta=delayedTime)

		user.setTutorialComplete()

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
	return True, classification, actionsByScore

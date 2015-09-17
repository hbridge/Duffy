import time
import pytz
import logging
import datetime
import string
import json
import random

from smskeeper import sms_util, tips
from smskeeper import keeper_constants, keeper_strings
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
				sms_util.sendMsg(user, random.choice(keeper_strings.ASK_AGAIN_FOR_NAME), None, keeperNumber)
				return True, keeper_constants.CLASS_NONE, actionScores
			else:
				user.name = msg.strip(string.punctuation)

		user.save()

		if user.product_id == keeper_constants.WHATSAPP_TODO_PRODUCT_ID:
			postalCodeMessage = keeper_strings.ASK_FOR_POSTAL_CODE_TEXT
		else:
			postalCodeMessage = keeper_strings.ASK_FOR_ZIPCODE_TEXT

		sms_util.sendMsgs(
			user,
			[
				random.choice(keeper_strings.GOT_NAME_RESPONSE) % user.getFirstName(),
				postalCodeMessage
			],
			keeperNumber
		)
		user.setStateData(keeper_constants.TUTORIAL_STEP_KEY, 1)
	elif step == 1:
		postalCode = msg_util.getPostalCode(msg)

		if postalCode:
			timezone, wxcode, tempFormat = msg_util.dataForPostalCode(postalCode)
			logger.debug("%s, %s, %s"%(timezone, wxcode, tempFormat))
			if timezone is None:
				sms_util.sendMsg(user, random.choice(keeper_strings.ZIPCODE_NOT_VALID_TEXT), None, keeperNumber)
				return True, keeper_constants.CLASS_NONE, actionScores
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
				sms_util.sendMsg(user, keeper_strings.ASK_AGAIN_FOR_ZIPCODE_TEXT, None, keeperNumber)
				return True, keeper_constants.CLASS_NONE, actionScores
			else:
				# else ignore
				return True, keeper_constants.CLASS_NONE, actionScores

		sms_util.sendMsgs(user, [random.choice(keeper_strings.TUTORIAL_POST_NAME_AND_ZIPCODE_TEXT), keeper_strings.TUTORIAL_STUDENT_ADD_FIRST_REMINDER_TEXT], keeperNumber)

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
			[keeper_strings.TUTORIAL_DONE_TEXT,
			],
			keeperNumber)

		delayedTime = date_util.now(pytz.utc) + datetime.timedelta(minutes=20)
		if user.product_id != keeper_constants.WHATSAPP_TODO_PRODUCT_ID:
			sms_util.sendMsg(user, keeper_strings.TUTORIAL_VCARD_AND_MORNING_DIGEST_TEXT, keeper_constants.KEEPER_TODO_VCARD_URL, keeperNumber, eta=delayedTime)
		else:
			sms_util.sendMsg(user, keeper_strings.TUTORIAL_MORNING_DIGEST_ONLY_TEXT, None, eta=delayedTime)

		# Ask for referral if needed
		signupData = json.loads(user.signup_data_json)
		if "source" not in signupData or ("fb" not in signupData["source"] and 'referrer' in signupData and len(signupData["referrer"]) == 0):
			referralTip = tips.tipWithId(tips.REFERRAL_ASK_TIP_ID)
			sms_util.sendMsg(user, referralTip.renderMini(), classification=tips.REFERRAL_ASK_TIP_ID, eta=delayedTime + datetime.timedelta(seconds=10))
			tips.markTipSent(user, referralTip, isMini=True)

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

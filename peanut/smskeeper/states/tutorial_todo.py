import time
import pytz
import logging
import datetime
import string

from smskeeper import sms_util
from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper import analytics, niceties, actions
from smskeeper.models import Message

from common import date_util

logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	step = user.getStateData("step")

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

	# Deal with one off things before we get to tutorial
	nicety = niceties.getNicety(msg)
	if nicety:
		actions.nicety(user, nicety, requestDict, keeperNumber)
		return True

	# Tutorial stuff
	if step == 0:
		# First see if they did a phrase like "my name is Billy"
		nameFromPhrase = msg_util.nameInSetName(msg, tutorial=True)

		if nameFromPhrase:
			user.name = nameFromPhrase
		else:
			# If there's more than two words, then reject
			if len(msg.split(' ')) > 2:
				sms_util.sendMsg(user, u"We'll get to that, but first what's your name?", None, keeperNumber)
				return True
			else:
				user.name = msg.strip(string.punctuation)

		user.save()
		sms_util.sendMsgs(
			user,
			[
				u"Great, nice to meet you %s! \U0001F44B" % user.getFirstName(),
				u"What's your zipcode? It'll help me remind you of things at the right time \U0001F553"
			],
			keeperNumber
		)
		user.setStateData("step", 1)
	elif step == 1:
		zipcode = msg_util.getZipcode(msg)

		if zipcode:
			timezone = msg_util.timezoneForZipcode(zipcode)
			if timezone is None:
				response = "Sorry, I don't know that zipcode. Could you check that?"
				sms_util.sendMsg(user, response, None, keeperNumber)
				return True
			else:
				user.zipcode = zipcode
				user.timezone = timezone
		else:
			logger.debug("postalCodes were none for: %s" % msg)
			lastMessageOut = Message.objects.filter(user=user, incoming=False).order_by("added").last()
			cutoff = date_util.now(pytz.utc) - datetime.timedelta(minutes=2)

			# If we last sent a message over 2 minutes ago, then send back I'm not sure
			if lastMessageOut.added < cutoff:
				response = "Got it, but first thing, what's your zipcode?"
				sms_util.sendMsg(user, response, None, keeperNumber)
				return True
			else:
				# else ignore
				return True

		sms_util.sendMsgs(user, [u"\U0001F44F Thanks! Let's add something you need to get done. \u2705", u"What's an item on your todo list right now? You can say things like 'Buy flip flops' or 'Pick up Susie at 2:30 Friday'."], keeperNumber)

		user.setStateData("step", 2)
		user.setState(keeper_constants.STATE_REMIND, saveCurrent=True)
		user.setStateData(keeper_constants.FROM_TUTORIAL_KEY, True)

	elif step == 2:
		time.sleep(1)
		sms_util.sendMsgs(
			user,
			[
				u"It's that easy. Just txt me when things pop in your head and I'll track them for you. \U0001F60E What else do you need to do?",
			],
			keeperNumber)

		delayedTime = date_util.now(pytz.utc) + datetime.timedelta(minutes=20)
		sms_util.sendMsg(user, u"Oh and I'll also send you a morning \U0001F304 digest of things you need to get done that day.", None, keeperNumber, eta=delayedTime)
		user.setTutorialComplete()

		entryId = user.getStateData(keeper_constants.ENTRY_ID_DATA_KEY)
		user.setState(keeper_constants.STATE_REMIND)
		# The remind state will pass this to us...so pass it back
		user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entryId)

		analytics.logUserEvent(
			user,
			"Completed Tutorial",
			{
				"Tutorial": keeper_constants.STATE_TUTORIAL_TODO
			}
		)
		analytics.setUserInfo(user)

	user.save()
	return True

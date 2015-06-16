import time
import re
import logging
import datetime
import string

from smskeeper import sms_util
from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper import analytics, niceties, actions
from smskeeper.models import Entry

# Might need to get ride of this at some point due to circular dependencies
# Its only using a few constants, easily moved
from smskeeper.states import remind

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
				u"Great, nice to meet you %s! \U0001F44B" % user.name,
				u"What's your zipcode? It'll help me remind you of things at the right time \U0001F553"
			],
			keeperNumber
		)
		user.setStateData("step", 1)
	elif step == 1:
		timezone, user_error = msg_util.timezoneForMsg(msg)

		if timezone is None:
			sms_util.sendMsg(user, user_error, None, keeperNumber)
			return True
		else:
			user.timezone = timezone

		sms_util.sendMsgs(user, [u"\U0001F44F Thanks! Let's add something you need to get done. \u2705", u"What's an item on your todo list right now? You can say things like 'Buy flip flops' or 'Pick up Susie at 2:30 Friday'."], keeperNumber )

		user.setStateData("step", 2)
		user.setState(keeper_constants.STATE_REMIND, saveCurrent=True)
		user.setStateData(keeper_constants.FROM_TUTORIAL_KEY, True)

	elif step == 2:
		# succeeded
		sms_util.sendMsgs(user, [u"What's something else you need to do?  just txt me what and when"], keeperNumber)
		user.setStateData("step", 3)
		user.setState(keeper_constants.STATE_REMIND, saveCurrent=True)
		user.setStateData(keeper_constants.FROM_TUTORIAL_KEY, True)

	elif step == 3:
		sms_util.sendMsgs(user, [u"I'll also send you a daily morning digest of things you need to get done that day."], keeperNumber)
		sms_util.sendMsgs(user, [u"Just txt me when things pop in your head and I'll track them for you. It's that easy. \U0001F60E"], keeperNumber)

		# TODO: enable tell me more
		#delayedTime = datetime.datetime.utcnow() + datetime.timedelta(minutes=20)
		#sms_util.sendMsg(user, "FYI, you can always say 'Tell me more' to learn more.", None, keeperNumber, eta=delayedTime)
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
	return True

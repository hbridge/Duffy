import time
import re
import logging

from smskeeper import sms_util
from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper import analytics

# Might need to get ride of this at some point due to circular dependencies
# Its only using a few constants, easily moved
from smskeeper.states import remind

logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	step = user.getStateData("step")

	if step:
		step = int(step)

	analytics.logUserEvent(
		user,
		"Reached Tutorial Step",
		{
			"Tutorial": keeper_constants.STATE_TUTORIAL_REMIND,
			"Step": step if step is not None else 0
		}
	)

	if not step:
		nameFromPhrase = msg_util.nameInTutorialPrompt(msg)
		if nameFromPhrase:
			user.name = nameFromPhrase
		else:
			user.name = msg.strip()
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

		sms_util.sendMsg(user, u"\U0001F44F Thanks! Let me show you how to set reminders \u23F0. Think of the last thing you wanted to be reminded of. Type it in with 'remind me'. For ex: 'Remind me to call Mom this weekend'. Try it now!", None, keeperNumber)

		# Setup the next state along with data saying we're going to it from the tutorial
		user.setState(keeper_constants.STATE_REMIND)
		user.setStateData(remind.FROM_TUTORIAL_KEY, True)

		# Make sure that we come back to the tutorial and don't goto NORMAL
		user.setNextState(keeper_constants.STATE_TUTORIAL_REMIND)
		user.setNextStateData("step", 2)
	elif step == 2:
		# Coming back from remind state so wait a second
		time.sleep(1)
		sms_util.sendMsgs(user, [u"K that's all set, what other reminders do you want to setup for next few days? Calls \U0001f4f1, emails \U0001F4E7, errands \U0001F45C?  I'm here to help! \U0001F60A", "FYI, I can also help you with other things. Just txt me 'Tell me more'"], keeperNumber)
		user.setTutorialComplete()
		analytics.logUserEvent(
			user,
			"Completed Tutorial",
			{
				"Tutorial": keeper_constants.STATE_TUTORIAL_REMIND
			}
		)

	user.save()
	return True

import time
import logging
import datetime
import string

from smskeeper import sms_util
from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper import analytics, niceties, actions

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
			"Tutorial": keeper_constants.STATE_TUTORIAL_REMIND,
			"Step": step
		}
	)

	# Deal with one off things before we get to tutorial
	nicety = niceties.getNicety(msg)
	if nicety:
		actions.nicety(user, nicety, requestDict, keeperNumber)
		return True, None

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
				return True, None
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
		user.setStateData(keeper_constants.TUTORIAL_STEP_KEY, 1)
	elif step == 1:
		postalCode = msg_util.getPostalCode(msg)

		if postalCode:
			timezone, wxcode = msg_util.dataForPostalCode(postalCode)
			if timezone is None:
				response = "Sorry, I don't know that zipcode. Could you check that?"
				sms_util.sendMsg(user, response, None, keeperNumber)
				return True, None
			else:
				user.postal_code = postalCode
				user.timezone = timezone
				user.wxcode = wxcode
		else:
			logger.debug("postalCodes were none for: %s" % msg)
			response = "Sorry, I didn't understand that, what's your zipcode?"
			sms_util.sendMsg(user, response, None, keeperNumber)
			return True, None

		sms_util.sendMsgs(user, [u"\U0001F44F Thanks! Let's set your first reminder. \u23F0", u"What's a recent thing you wanted to be reminded of? Like 'Remind me to order birthday cake this weekend'. Give it a try - just start with 'Remind me...'!"], keeperNumber)

		user.setStateData(keeper_constants.TUTORIAL_STEP_KEY, 2)
		user.setState(keeper_constants.STATE_REMIND)
		user.setNextState(keeper_constants.STATE_TUTORIAL_REMIND)
	elif step == 2:
		# Coming back from remind state so wait a second
		if keeper_constants.isRealKeeperNumber(keeperNumber):
			time.sleep(1)
		sms_util.sendMsgs(user, [u"K that's all set, what other reminders do you want to setup for next few days? Calls \U0001f4f1, emails \U0001F4E7, errands \U0001F45C?  I'm here to help! \U0001F60A"], keeperNumber)
		delayedTime = datetime.datetime.utcnow() + datetime.timedelta(minutes=20)
		sms_util.sendMsg(user, "FYI, I can also help you with other things. Just txt me 'Tell me more'", None, keeperNumber, eta=delayedTime)
		user.setTutorialComplete()

		user.setState(keeper_constants.STATE_REMIND)

		analytics.logUserEvent(
			user,
			"Completed Tutorial",
			{
				"Tutorial": keeper_constants.STATE_TUTORIAL_REMIND
			}
		)
		analytics.setUserInfo(user)

	user.save()
	return True, None

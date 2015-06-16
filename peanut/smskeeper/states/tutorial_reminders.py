import time
import logging
import datetime
import string

from smskeeper import sms_util
from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper import analytics, niceties, actions
from smskeeper.models import Entry

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
			"Tutorial": keeper_constants.STATE_TUTORIAL_REMIND,
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

		sms_util.sendMsgs(user, [u"\U0001F44F Thanks! Let's set your first reminder. \u23F0", u"What's a recent thing you wanted to be reminded of? Like 'Remind me to order birthday cake this weekend'. Give it a try - just start with 'Remind me...'!"], keeperNumber )

		# Setup the next state along with data saying we're going to it from the tutorial
		user.setState(keeper_constants.STATE_REMIND)
		user.setStateData(keeper_constants.FROM_TUTORIAL_KEY, True)

		# Make sure that we come back to the tutorial and don't goto NORMAL
		user.setNextState(keeper_constants.STATE_TUTORIAL_REMIND)
		user.setNextStateData("step", 2)
	elif step == 2:
		# Coming back from remind state so wait a second
		time.sleep(1)
		sms_util.sendMsgs(user, [u"K that's all set, what other reminders do you want to setup for next few days? Calls \U0001f4f1, emails \U0001F4E7, errands \U0001F45C?  I'm here to help! \U0001F60A"], keeperNumber)
		delayedTime = datetime.datetime.utcnow() + datetime.timedelta(minutes=20)
		sms_util.sendMsg(user, "FYI, I can also help you with other things. Just txt me 'Tell me more'", None, keeperNumber, eta=delayedTime)
		user.setTutorialComplete()

		entryId = user.getStateData(keeper_constants.ENTRY_ID_DATA_KEY)
		user.setState(keeper_constants.STATE_REMIND)
		# The remind state will pass this to us...so pass it back
		user.setStateData(keeper_constants.ENTRY_ID_DATA_KEY, entryId)

		analytics.logUserEvent(
			user,
			"Completed Tutorial",
			{
				"Tutorial": keeper_constants.STATE_TUTORIAL_REMIND
			}
		)
		analytics.setUserInfo(user)

	user.save()
	return True

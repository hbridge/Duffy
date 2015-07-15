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
	step = user.getStateData("step")

	if step:
		step = int(step)
	else:
		step = 0

	analytics.logUserEvent(
		user,
		"Reached Tutorial Step",
		{
			"Tutorial": keeper_constants.STATE_TUTORIAL_LIST,
			"Step": step
		}
	)

	# Deal with one off things before we get to tutorial
	nicety = niceties.getNicety(msg)
	if nicety:
		actions.nicety(user, nicety, requestDict, keeperNumber)
		classification = keeper_constants.CLASS_SILENT_NICETY if nicety.isSilent() else keeper_constants.CLASS_NICETY
		return True, classification

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
				return True, keeper_constants.CLASS_NONE
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
		postalCode = msg_util.getPostalCode(msg)

		if postalCode:
			timezone = msg_util.timezoneForPostalCode(postalCode)
			if timezone is None:
				response = "Sorry, I don't know that zipcode. Could you check that?"
				sms_util.sendMsg(user, response, None, keeperNumber)
				return True, keeper_constants.CLASS_NONE
			else:
				user.postal_code = postalCode
				user.timezone = timezone
		else:
			logger.debug("postalCodes were none for: %s" % msg)
			response = "Sorry, I didn't understand that, what's your zipcode?"
			sms_util.sendMsg(user, response, None, keeperNumber)

		sms_util.sendMsgs(user,
			[
				u"\U0001F44F Thanks! Let's add some things you want to remember. ",
				u"What's a recent thing you wanted to buy? You can say 'Add pasta to my shopping list'. Give it a try - just start with 'Add...'!"
			],
			keeperNumber)

		user.setStateData("step", 2)
	elif step == 2:

		if msg_util.isAddTextCommand(msg):
			actions.add(user, msg, requestDict, keeperNumber, True, True)
		else:
			sms_util.sendMsgs(
				user,
				[
					u"I didn't understand that \U0001F61E. Try saying it as 'Add ITEM to LIST'"
				],
				keeperNumber)
			return True, None

		# time.sleep so the response to add Action goes out first
		if keeper_constants.isRealKeeperNumber(keeperNumber):
			time.sleep(1)
		sms_util.sendMsgs(
			user,
			[
				u"Now let's add other items to your list. Like 'Add meatballs, cheese to shopping list'"
			],
			keeperNumber
			)

		user.setStateData("step", 3)

	elif step == 3:

		if msg_util.isAddTextCommand(msg):
			actions.add(user, msg, requestDict, keeperNumber, True, True)
		else:
			sms_util.sendMsgs(
				user,
				[
					u"I didn't understand that \U0001F61E. Try saying it as 'Add ITEM to LIST'"
				],
				keeperNumber
				)
			return True, None

		sms_util.sendMsgs(
			user,
			[
				u"Great! You can add items to this list anytime (including photos). To see items on a list, just ask for it 'my shopping list'. Give it a shot."
			],
			keeperNumber
			)

		user.setStateData("step", 4)

	elif step == 4:

		if msg_util.isFetchCommand(msg, user):
			actions.fetch(user, msg_util.labelInFetch(msg), keeperNumber)
		else:
			sms_util.sendMsgs(
				user,
				[
					u"I didn't understand that \U0001F61E. Try saying it as 'shopping list'"
				],
				keeperNumber
				)
			return True, None

		sms_util.sendMsgs(
			user,
			[
				u"You got it. What's something else you want to remember?",
				u"Like movies to watch, restaurants to try, books to read, or even a food journal. Give it a shot \U0001F44D",
			],
			keeperNumber
			)

		delayedTime = datetime.datetime.utcnow() + datetime.timedelta(minutes=20)
		sms_util.sendMsg(user, "FYI, I can also help you with other things. Just txt me 'Tell me more'", None, keeperNumber, eta=delayedTime)
		user.setTutorialComplete()
		user.setState(keeper_constants.STATE_NORMAL)

		analytics.logUserEvent(
			user,
			"Completed Tutorial",
			{
				"Tutorial": keeper_constants.STATE_TUTORIAL_LIST
			}
		)
		analytics.setUserInfo(user)

	user.save()
	return True, None
import time

from smskeeper import sms_util
from smskeeper import keeper_constants

# Might need to get ride of this at some point due to circular dependencies
# Its only using a few constants, easily moved
from smskeeper.states import remind


def process(user, msg, requestDict, keeperNumber):
	step = user.getStateData("step")
	if step:
		step = int(step)

	if not step:
		user.name = msg
		user.save()
		sms_util.sendMsg(user, "Great, nice to meet you %s!" % user.name, None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "Let me show you how to set a reminder. Just say 'Remind me to call mom this weekend' or 'Remind me to pickup laundry at 7pm tonight'. Try creating one now.", None, keeperNumber)

		# Setup the next state along with data saying we're going to it from the tutorial
		user.setState(keeper_constants.STATE_REMIND)
		user.setStateData(remind.FROM_TUTORIAL_KEY, True)

		# Make sure that we come back to the tutorial and don't goto NORMAL
		user.setNextState(keeper_constants.STATE_TUTORIAL_REMIND)
		user.setNextStateData("step", 1)
	elif step == 1:
		# Coming back from remind state so wait a second
		time.sleep(1)
		sms_util.sendMsgs(user, ["What else do you want to be reminded about?", "FYI, I can also help you with other things. Just txt me 'Tell me more'"], keeperNumber)
		user.setTutorialComplete()

	user.save()
	return True

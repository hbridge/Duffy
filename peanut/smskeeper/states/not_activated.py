import random
import string

from smskeeper import sms_util, msg_util, user_util
from smskeeper import keeper_constants


def dealWithNonActivatedUser(user, keeperNumber):
	if user.getStateData("step") is None:
		code = ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(6))
		url = "getkeeper.com/" + code

		messages = ["Hi. I'm Keeper. I can help you remember things quickly. You've been added to the waiting list.",
					"Want seamless organization now? Have a friend sign up and get Keeper instantly: %s" % url
					]

		sms_util.sendMsgs(user, messages, keeperNumber)
		user.setStateData("step", 1)
		user.invite_code = code
		user.save()


def process(user, msg, requestDict, keeperNumber):
	text, label, handles = msg_util.getMessagePieces(msg)

	# If the user enters the magic phrase then they get activated
	if msg_util.isMagicPhrase(text):
		user_util.activate(user, keeper_constants.FIRST_INTRO_MESSAGE_MAGIC, None, keeperNumber)
	# If not, then give them back some fun remarks
	else:
		dealWithNonActivatedUser(user, keeperNumber)

	return True

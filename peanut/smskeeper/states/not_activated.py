import time
import random
import string

from smskeeper import sms_util, msg_util, user_util
from smskeeper import keeper_constants


def dealWithNonActivatedUser(user, keeperNumber):
	if user.getStateData("step") is None:
		sms_util.sendMsg(user, "Hi. I'm Keeper. I can help you remember things quickly.", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "You are on the waiting list. I'll be in touch as soon as I'm ready for you.", None, keeperNumber)
		user.setStateData("step", 1)
		user.save()
	elif user.getStateData("step") == 1:
		code = ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(6))
		user.invite_code = code
		user.setStateData("step", 2)
		user.save()

		url = "getkeeper.com/" + code
		sms_util.sendMsg(user, "FYI, if you'd like to get off the waiting list, get 1 friend to sign up at this url: %s " % url, None, keeperNumber)


def process(user, msg, requestDict, keeperNumber):
	text, label, handles = msg_util.getMessagePieces(msg)

	# If the user enters the magic phrase then they get activated
	if msg_util.isMagicPhrase(text):
		user_util.activate(user, keeper_constants.FIRST_INTRO_MESSAGE_MAGIC, None, keeperNumber)
	# If not, then give them back some fun remarks
	else:
		dealWithNonActivatedUser(user, keeperNumber)

	return True

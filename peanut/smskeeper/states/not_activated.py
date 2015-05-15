import time
import random

from smskeeper import sms_util, msg_util, user_util
from smskeeper import keeper_constants


def dealWithNonActivatedUser(user, keeperNumber):
	if user.state_data is None:
		sms_util.sendMsg(user, "Hi. I'm Keeper. I can help you remember things quickly.", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "You are on the waiting list. I'll be in touch as soon as I'm ready for you.", None, keeperNumber)
		user.state_data = "1"
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

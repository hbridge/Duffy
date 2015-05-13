import time
import random
import datetime
import pytz

from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants
import tutorial

def dealWithNonActivatedUser(user, keeperNumber):
	if user.state_data == None:
		sms_util.sendMsg(user, "Hi. I'm Keeper. I can help you remember things quickly.", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "Hmm... you aren't on my guest list. What's the magic phrase?", None, keeperNumber)
		user.state_data = "1"
		user.save()
	elif user.state_data == "1":
		reply = ["Nope. That's not it. :p"]
		sms_util.sendMsg(user, random.choice(reply), None, keeperNumber)
		user.state_data = "2"
		user.save()
	elif user.state_data == "2":
		reply = ["Nice try. Except it didn't work. \xF0\x9F\x98\x88"]
		sms_util.sendMsg(user, random.choice(reply), None, keeperNumber)
		user.state_data = "3"
		user.save()
	else:
		reply = [
			"They don't make magic phrases like they used to",
			"Who gave you my number?!? I'm going to report you",
			"You know there are laws against this kind of thing",
			"Quantity is not the same thing as quality"
		]
		sms_util.sendMsg(user, random.choice(reply), None, keeperNumber)


def dealWithMagicPhrase(user, keeperNumber):
	user.activate()
	sms_util.sendMsgs(user, ["That's the magic phrase. Welcome!"] + keeper_constants.INTRO_MESSAGES, keeperNumber)

def process(user, msg, requestDict, keeperNumber):
	text, label, handles = msg_util.getMessagePieces(msg)

	# If the user enters the magic phrase then they get activated
	if msg_util.isMagicPhrase(text):
		dealWithMagicPhrase(user, keeperNumber)

	# If not, then give them back some fun remarks
	else:
		dealWithNonActivatedUser(user, keeperNumber)

	return True

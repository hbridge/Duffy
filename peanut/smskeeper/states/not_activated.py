import time
import random
import datetime
import pytz

from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants

def dealWithNonActivatedUser(user, keeperNumber):
	if user.state_data == None:
		sms_util.sendMsg(user, "Hi. I'm Keeper.", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "I can help you remember things. But, first I need the magic phrase to get you started.", None, keeperNumber)
		user.state_data = "1"
		user.save()
	elif user.state_data == "1":
		reply = "Nope. That's not it. :p"
		sms_util.sendMsg(user, reply, None, keeperNumber)
		user.state_data = "2"
		user.save()
	elif user.state_data == "2":
		reply = u"Nice try. Except it didn't work. \xF0\x9F\x98\x88"
		sms_util.sendMsg(user, reply, None, keeperNumber)
		user.state_data = "3"
		user.save()
	else:
		incorrectPhraseResponses = ["They don't make magic phrases like they used to",
									"Who gave you my number?!? I'm going to report you",
									"You know there are laws against this kind of thing",
									"Quantity is not the same thing as quality"]
		sms_util.sendMsg(user, random.choice(incorrectPhraseResponses), None, keeperNumber)

def dealWithMagicPhrase(user, keeperNumber):
	user.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	user.state = keeper_constants.STATE_TUTORIAL
	user.save()
	
	sms_util.sendMsg(user, "That's the magic phrase. Let's get started", None, keeperNumber)
	time.sleep(1)
	sms_util.sendMsg(user, "I'm Keeper and I can keep track of your lists, notes, photos, etc.", None, keeperNumber)
	time.sleep(1)
	sms_util.sendMsg(user, "Before I explain a bit more, what's your name?", None, keeperNumber)


def process(user, msg, numMedia, requestDict, keeperNumber):
	text, label, handles = msg_util.getMessagePieces(msg)

	# If the user enters the magic phrase then they get activated
	if msg_util.isMagicPhrase(text):
		dealWithMagicPhrase(user, keeperNumber)

	# If not, then give them back some fun remarks
	else:
		dealWithNonActivatedUser(user, keeperNumber)

import time
from smskeeper import sms_util
import random
import keeper_constants

def firstRunIntro(user, keeperNumber):
	sms_util.sendMsg(user, "I'm Keeper and I can help you remember those small things like a shopping list, movies to watch, or wines you liked.", None, keeperNumber)
	time.sleep(1)
	sms_util.sendMsg(user, "Instead of writing them down somewhere (or forgetting to), just txt me.", None, keeperNumber)
	time.sleep(1)
	sms_util.sendMsg(user, "I'll show you how to interact with me. First, what's your name?", None, keeperNumber)

def sendNotFoundMessage(user, label, keeperNumber):
	sms_util.sendMsg(user, "Sorry, I don't have anything for %s" % label, None, keeperNumber)

def randomAcknowledgement():
	return random.choice(keeper_constants.ACKNOWLEDGEMENT_PHRASES)

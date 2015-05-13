import time
from smskeeper import sms_util
import random
import keeper_constants

def sendNotFoundMessage(user, label, keeperNumber):
	sms_util.sendMsg(user, "Sorry, I don't have anything for %s" % label, None, keeperNumber)

def randomAcknowledgement():
	return random.choice(keeper_constants.ACKNOWLEDGEMENT_PHRASES)
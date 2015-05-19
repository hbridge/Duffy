import time
from smskeeper import sms_util
import random
import keeper_constants

def sendNotFoundMessage(user, label, keeperNumber):
	if label == keeper_constants.REMIND_LABEL:
		sms_util.sendMsg(user, "You don't have any reminders scheduled. Say 'remind me to...' to add a reminder.", None, keeperNumber)
	label = label.replace("#", "")
	sms_util.sendMsg(user, "You don't have anything in your %s list. Say 'add ITEM to %s' to add something to it." % (label, label), None, keeperNumber)

def randomAcknowledgement():
	return random.choice(keeper_constants.ACKNOWLEDGEMENT_PHRASES)

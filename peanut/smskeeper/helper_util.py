
from smskeeper import sms_util
from smskeeper import keeper_constants, keeper_strings
import random
import phonenumbers
from phonenumbers import geocoder


def sendNotFoundMessage(user, label, keeperNumber):
	if label == keeper_constants.REMIND_LABEL:
		sms_util.sendMsg(user, "You don't have any reminders scheduled. Say 'remind me to...' to add a reminder.", None, keeperNumber)
	label = label.replace("#", "")
	sms_util.sendMsg(user, "You don't have anything in your %s list. Say 'add ITEM to %s' to add something to it." % (label, label), None, keeperNumber)


def randomAcknowledgement():
	return random.choice(keeper_strings.ACKNOWLEDGEMENT_PHRASES)


def isUSRegionCode(phoneNumber):
	number = phonenumbers.parse(phoneNumber, None)
	regionCode = geocoder.region_code_for_number(number)
	if 'US' in regionCode:
		return True
	else:
		return False

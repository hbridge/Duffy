import json
from twilio.rest.lookups import TwilioLookupsClient
from peanut.settings import constants
from smskeeper.whatsapp import whatsapp_util
from smskeeper import keeper_constants

import logging
logger = logging.getLogger(__name__)

LONG_MESSAGE_CARRIER_CODE_BLACKLIST = [
	"012",  # "Verizon Wireless",
	"120",  # "Sprint Spectrum, L.P."
]


def updatePhoneInfoForUser(user):
	client = TwilioLookupsClient(constants.TWILIO_ACCOUNT, constants.TWILIO_TOKEN)
	try:
		info = client.phone_numbers.get(user.phone_number, include_carrier_info=True)
		user.carrier_info_json = json.dumps(info.carrier)
		user.save()
		logger.info('User %d: found carrier: %s', user.id, info.carrier.get('name', "null"))
	except Exception as e:
		logger.error("Couldn't set phoneInfoFor user %d: %s", user.id, e)


def getUserCarrierInfo(user):
	keeperNumber = user.getKeeperNumber()
	if whatsapp_util.isWhatsappNumber(keeperNumber):
		return {
			"mobile_network_code": "0",
			"name": "whatsapp"
		}
	elif user.carrier_info_json is None or user.carrier_info_json == "":
		if not keeper_constants.isRealKeeperNumber(keeperNumber):
			return {
				"mobile_network_code": "0",
				"name": "test"
			}
		return None

	carrierInfo = None
	try:
		carrierInfo = json.loads(user.carrier_info_json)
	except Exception as e:
		logger.error("Couldn't load carrier info for user %d: %s", user.id, e)

	return carrierInfo


def userCarrierSupportsLongSMS(user):
	carrierInfo = getUserCarrierInfo(user)
	if not carrierInfo:
		return True

	carrierNumber = carrierInfo.get('mobile_network_code', 0)
	if carrierNumber in LONG_MESSAGE_CARRIER_CODE_BLACKLIST:
		return False

	return True

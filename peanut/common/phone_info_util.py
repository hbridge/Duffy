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


def fetchCarrierInfoJsonForUser(user):
	carrierInfo = None
	keeperNumber = user.getKeeperNumber()

	# if this is a fake number or a whatsapp number, don't ask twilio
	if whatsapp_util.isWhatsappNumber(keeperNumber):
		carrierInfo = {
			"mobile_network_code": "0",
			"name": "whatsapp"
		}
	elif not keeper_constants.isRealKeeperNumber(keeperNumber):
		carrierInfo = {
			"mobile_network_code": "0",
			"name": "test"
		}
	else:  # otherwise, look it up from twilio
		client = TwilioLookupsClient(constants.TWILIO_ACCOUNT, constants.TWILIO_TOKEN)
		try:
			info = client.phone_numbers.get(user.phone_number, include_carrier_info=True)
			carrierInfo = info.carrier
			logger.info('User %d: found carrier: %s', user.id, info.carrier.get('name', "null"))
		except Exception as e:
			logger.error("Couldn't get carrier info from Twillio for user %d: %s", user.id, e)
			return None

	return json.dumps(carrierInfo)


def getUserCarrierInfo(user):
	carrierInfo = None

	if user.carrier_info_json is None or user.carrier_info_json == "":
		return None

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

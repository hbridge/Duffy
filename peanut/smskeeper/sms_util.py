import json
import logging

from smskeeper.models import Message
from strand import notifications_util
logger = logging.getLogger(__name__)

def sendMsg(user, msg, mediaUrls, keeperNumber):
	msgJson = {"Body": msg, "To": user.phone_number, "From": keeperNumber, "MediaUrls": mediaUrls}
	Message.objects.create(user=user, incoming=False, msg_json=json.dumps(msgJson))
	
	if keeperNumber == "test":
		# This is used for command line interface commands
		# If you change this, all tests will fail.
		# TODO: figure out how to pipe this with logger
		print msg
	else:
		if mediaUrls:
			notifications_util.sendSMSThroughTwilio(user.phone_number, msg, mediaUrls, keeperNumber)
		else:
			notifications_util.sendSMSThroughTwilio(user.phone_number, msg, None, keeperNumber)
		logger.info("Sending %s to %s" % (msg.decode('utf-8'), user.phone_number))

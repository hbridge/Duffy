import json
import logging

from smskeeper.models import Message
from strand import notifications_util

from peanut.settings import constants

logger = logging.getLogger(__name__)

def sendMsg(user, msg, mediaUrls, keeperNumber):
	msgJson = {"Body": msg, "To": user.phone_number, "From": keeperNumber, "MediaUrls": mediaUrls}
	Message.objects.create(user=user, incoming=False, msg_json=json.dumps(msgJson))

	if type(msg) == unicode:
		msg = msg.encode('utf-8')
	
	if keeperNumber == constants.SMSKEEPER_TEST_NUM:
		# This is used for command line interface commands
		# If you change this, all tests will fail.
		# TODO: figure out how to pipe this with logger
		print msg
	else:
		if mediaUrls:
			notifications_util.sendSMSThroughTwilio(user.phone_number, msg, mediaUrls, keeperNumber)
		else:
			notifications_util.sendSMSThroughTwilio(user.phone_number, msg, None, keeperNumber)
		logger.info("Sending %s to %s" % (msg, str(user.phone_number)))

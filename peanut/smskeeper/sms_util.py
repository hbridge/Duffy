import json
import logging

from smskeeper.models import Message
from strand import notifications_util

from peanut.settings import constants

logger = logging.getLogger(__name__)

"""
	This is used for testing, it gets mocked out
	The sendMsg method calls it as well for us in the command line interface
"""
def recordOutput(msg, doPrint=False):
	if doPrint:
		print msg

def sendMsg(user, msg, mediaUrls, keeperNumber):
	msgJson = {"Body": msg, "To": user.phone_number, "From": keeperNumber, "MediaUrls": mediaUrls}
	Message.objects.create(user=user, incoming=False, msg_json=json.dumps(msgJson))

	if type(msg) == unicode:
		msg = msg.encode('utf-8')

	if keeperNumber == constants.SMSKEEPER_CLI_NUM:
		# This is used for command line interface commands
		recordOutput(msg, True)
	elif keeperNumber == constants.SMSKEEPER_TEST_NUM:
		recordOutput(msg, False)
	else:
		if mediaUrls:
			notifications_util.sendSMSThroughTwilio(user.phone_number, msg, mediaUrls, keeperNumber)
		else:
			notifications_util.sendSMSThroughTwilio(user.phone_number, msg, None, keeperNumber)
		logger.info("Sending %s to %s" % (msg, str(user.phone_number)))

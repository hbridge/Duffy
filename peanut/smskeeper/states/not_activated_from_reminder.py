import pytz
import logging
import json

from django.conf import settings

from smskeeper import niceties, sms_util, keeper_constants, user_util
from common import slack_logger, date_util

logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	nicety = niceties.getNicety(msg)
	if nicety:
		response = nicety.getResponse(user, requestDict, user.getKeeperNumber())
		if not response:
			response = ":thumbs_up_sign:"
		response = "%s %s" % (response, keeper_constants.SHARED_REMINDER_RECIPIENT_UPSELL)
		sms_util.sendMsg(user, response, None, keeperNumber)
	elif "tell me more" in msg.lower():
		user.signup_data_json = json.dumps({"source": "reminder"})
		user_util.activateUser(user, None, keeperNumber)
		user.save()
	elif not settings.DEBUG:
		user.paused = True
		user.save()
		logger.info("Putting user %s into paused state due to the message %s" % (user.id, msg))

		now = date_util.now(pytz.timezone("US/Eastern"))
		if now.hour >= 9 and now.hour <= 22 and keeperNumber != keeper_constants.SMSKEEPER_TEST_NUM:
			postMsg = "User %s paused after: %s" % (user.id, msg)
			slack_logger.postManualAlert(user, postMsg, keeperNumber, keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)

	return True, keeper_constants.CLASS_NONE, dict()

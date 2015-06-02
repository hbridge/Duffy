import datetime
import pytz
import logging
import json

from django.conf import settings

from smskeeper import niceties, actions, sms_util, keeper_constants, user_util
from common import slack_logger

logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	nicety = niceties.getNicety(msg)
	if nicety:
		actions.nicety(user, nicety, requestDict, keeperNumber)  # This sends "No problem"
		msgFollowup = "btw, if you'd like to learn more about me just txt me 'tell me more' or visit http://getkeeper.com"
		sms_util.sendMsg(user, msgFollowup, None, keeperNumber)
	elif "tell me more" in msg.lower():
		user.signup_data_json = json.dumps({"source": "reminder"})
		user.save()
		user_util.activate(user, "", None, keeperNumber)
	elif not settings.DEBUG:
		user.paused = True
		user.save()
		logger.info("Putting user %s into paused state due to the message %s" % (user.id, msg))

		now = datetime.datetime.now(pytz.timezone("US/Eastern"))
		if now.hour >= 9 and now.hour <= 22 and keeperNumber != keeper_constants.SMSKEEPER_TEST_NUM:
			postMsg = "User %s paused after: %s" % (user.id, msg)
			slack_logger.postManualAlert(user, postMsg, keeperNumber, keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)

	return True

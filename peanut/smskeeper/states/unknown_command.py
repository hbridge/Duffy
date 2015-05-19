import re
from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants
from common import slack_logger
from smskeeper.models import Message

RECENT_MESSAGES_TO_POST = 10


def process(user, msg, requestDict, keeperNumber):
	processed = False

	# If the user enters report, let them know we've been notified
	if re.match(keeper_constants.REPORT_ISSUE_KEYWORD, msg_util.cleanMsgText(msg)) is not None:
		sms_util.sendMsg(user, keeper_constants.REPORT_ISSUE_CONFIRMATION, None, keeperNumber)
		recentMessages = Message.objects.filter(user=user).order_by("-added")
		recentMessages = recentMessages[:RECENT_MESSAGES_TO_POST]
		# recentMessages.reverse()
		slack_logger.postUserReport(user.id, recentMessages)
		processed = True

	user.state = keeper_constants.STATE_NORMAL
	user.save()

	return processed

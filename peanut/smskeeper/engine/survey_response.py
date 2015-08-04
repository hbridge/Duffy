import logging

from smskeeper import keeper_constants
from .action import Action
from smskeeper import sms_util


logger = logging.getLogger(__name__)


class SurveyResponseAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_SURVEY_RESPONSE

	def getScore(self, chunk, user):
		score = 0.0

		justNotified = (user.state == keeper_constants.STATE_REMINDER_SENT)

		try:
			int(chunk.normalizedText())

			if justNotified:
				score = 1.0
			else:
				score = .7
		except ValueError:
			pass

		return score

	def execute(self, chunk, user):
		sms_util.sendMsg(user, "Got it, thanks.")
		return True

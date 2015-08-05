import logging

from smskeeper import keeper_constants
from .action import Action
from smskeeper import sms_util


logger = logging.getLogger(__name__)


class SurveyResponseAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_SURVEY_RESPONSE

	def isInt(self, word):
		try:
			int(word)
			return True
		except ValueError:
			return False

	def getScore(self, chunk, user):
		score = 0.0

		justNotified = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SURVEY)

		try:
			hasInt = False
			words = chunk.normalizedText().split(' ')

			hasIntFirst = self.isInt(words[0])

			for word in words:
				if self.isInt(word):
					hasInt = True

			if justNotified:
				if hasInt:
					if len(words) == 1:
						score = 1.0
					elif hasIntFirst:
						score = .7
				else:
					score = 0.1

		except ValueError:
			pass

		return score

	def execute(self, chunk, user):
		sms_util.sendMsg(user, "Got it, thanks.")
		return True

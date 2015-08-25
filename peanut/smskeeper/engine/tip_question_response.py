import logging

from smskeeper import keeper_constants
from .action import Action
from smskeeper import sms_util, actions, chunk_features
from smskeeper import analytics

logger = logging.getLogger(__name__)


class TipQuestionResponseAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_TIP_QUESTION_RESPONSE

	def isInt(self, word):
		try:
			int(word)
			return True
		except ValueError:
			return False

	def getScore(self, chunk, user):
		score = 0.0

		chunkFeatures = chunk_features.ChunkFeatures(chunk, user)

		# things that match this RE will get a minus
		containsReminderWord = chunkFeatures.hasCreateWord()
		beginsWithReminderWord = chunkFeatures.beginsWithCreateWord()

		# Check for survey
		surveyJustNotified = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SURVEY)

		try:
			hasInt = False
			words = chunk.normalizedText().split(' ')

			hasIntFirst = self.isInt(words[0])

			for word in words:
				if self.isInt(word):
					hasInt = True

			if surveyJustNotified:
				if hasInt:
					if len(words) == 1:
						score = 1.0
					elif hasIntFirst:
						score = .7
				else:
					score = 0.1

		except ValueError:
			pass

		# Check for digest change time
		digestChangeTimeJustNotified = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_CHANGE_DIGEST_TIME, 2)

		if digestChangeTimeJustNotified:
			nattyResult = chunk.getNattyResult(user)
			if nattyResult:
				if nattyResult.hadTime and not nattyResult.hadDate:
					score = .95
				else:
					score = .4
			else:
				score = .5

			if containsReminderWord and score > .5:
				score -= .2

			if beginsWithReminderWord and score > .5:
				score -= .4

		return score

	def execute(self, chunk, user):
		words = chunk.normalizedText().split(' ')

		# Note: Should we pass in the thing we matched on above down here?
		# Only applies to rules that have multiple small things
		surveyJustNotified = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SURVEY)
		digestChangeTimeJustNotified = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_CHANGE_DIGEST_TIME, 2)

		if surveyJustNotified:
			firstInt = None
			for word in words:
				if self.isInt(word):
					firstInt = int(word)
					break

			if firstInt:
				if firstInt < 3:
					sms_util.sendMsg(user, "Got it, I won't send you a morning txt when there are no tasks")
					user.digest_state = keeper_constants.DIGEST_STATE_LIMITED
					user.save()
				elif firstInt == 3:
					sms_util.sendMsg(user, "Got it, thanks.")
				else:
					sms_util.sendMsg(user, "Great to hear!")

				analytics.logUserEvent(
					user,
					"Digest survey",
					{"Score": firstInt}
				)
			else:
				return False
		elif digestChangeTimeJustNotified:
			return actions.updateDigestTime(user, chunk)
		else:
			return False

		return True

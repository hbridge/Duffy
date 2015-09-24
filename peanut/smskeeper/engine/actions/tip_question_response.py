import logging
import json

from smskeeper import keeper_constants, keeper_strings
from .action import Action
from smskeeper import sms_util, actions, chunk_features
from smskeeper import analytics, tips

logger = logging.getLogger(__name__)


class TipQuestionResponseAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_TIP_QUESTION_RESPONSE

	SURVEY = 0
	NPS = 1
	REFERRAL = 2
	DIGEST_CHANGE = 3

	# Different types of questions this class handles
	TYPES = [SURVEY, NPS, REFERRAL, DIGEST_CHANGE]

	def isInt(self, word):
		try:
			int(word)
			return True
		except ValueError:
			return False

	def getFirstInt(self, chunk):
		words = chunk.normalizedText().split(' ')
		for word in words:
			if self.isInt(word):
				firstInt = int(word)
				return firstInt
		return None

	def getScoreFunc(self, func):
		funcs = {self.SURVEY: self.surveyScore,
											self.NPS: self.npsScore,
											self.REFERRAL: self.referralScore,
											self.DIGEST_CHANGE: self.digestChangeScore}
		return funcs[func]

	# Returns back the score and which question type we think is the best match
	def getHighestScoreWithType(self, features):
		score = 0.0
		typeId = -1

		for x in self.TYPES:
			func = self.getScoreFunc(x)
			funcScore = func(features)

			if funcScore > score:
				score = funcScore
				typeId = x

		return score, typeId

	def getIntResponseScore(self, justNotified, features):
		score = 0.0

		if justNotified:
			if features.hasInt():
				if features.numWords() == 1:
					score = 1.0
				elif features.hasIntFirst():
					score = .7
			else:
				score = 0.1
		return score

	def surveyScore(self, features):
		score = 0.0

		digestSurveyJustNotified = features.wasRecentlySentMsgOfClassDigestSurvey()
		npsJustNotified = features.wasRecentlySentMsgOfClassNpsTip()

		# nps comes after survey, so assume answer is most recent
		# hacky here
		if digestSurveyJustNotified and not npsJustNotified and features.userMissingDigestSurveyInfo():
			score = self.getIntResponseScore(digestSurveyJustNotified, features)

		return score

	def npsScore(self, features):
		score = 0.0

		if features.wasRecentlySentMsgOfClassNpsTip() and features.userMissingNpsInfo():
			score = self.getIntResponseScore(features.wasRecentlySentMsgOfClassNpsTip(), features)

		return score

	def referralScore(self, features):
		score = 0.0

		# Only score if we don't have any current referrer
		# So we don't score anything on the second message
		if (features.wasRecentlySentMsgOfClassReferralAsk() and features.userMissingReferralInfo()):
			score = .6

		return score

	def digestChangeScore(self, features):
		score = 0.0

		if features.wasRecentlySentMsgOfClassChangeDigestTime():
			if features.hasTimingInfo():
				if features.hasTimeOfDay() and not features.hasDate():
					score = .95
				else:
					score = .4
			else:
				score = .5

			if features.hasCreateWord() and score > .5:
				score -= .2

			if features.beginsWithCreateWord() and score > .5:
				score -= .4

		return score

	def getScore(self, chunk, user):
		score = 0.0

		features = chunk_features.ChunkFeatures(chunk, user)

		score, typeId = self.getHighestScoreWithType(features)

		# none of our questions ask for a phone number at the moment, and this could conflict with resolve handle
		if features.hasPhoneNumber():
			score -= 0.5

		return score

	def execute(self, chunk, user):
		features = chunk_features.ChunkFeatures(chunk, user)
		score, typeId = self.getHighestScoreWithType(features)

		firstInt = self.getFirstInt(chunk)

		if score > 0:
			if typeId == self.NPS:
				if firstInt is not None:
					if firstInt < 8:
						sms_util.sendMsg(user, keeper_strings.QUESTION_ACKNOWLEDGE_OK_RESPONSE_TEXT)
					else:
						sms_util.sendMsg(user, keeper_strings.QUESTION_ACKNOWLEDGE_GREAT_RESPONSE_TEXT)

					logger.info("User %s: Logging a score of %s for nps" % (user.id, firstInt))
					user.setStateData(keeper_constants.NPS_DATA_KEY, firstInt)
					analytics.logUserEvent(
						user,
						"Digest nps response",
						{"Score": firstInt}
					)
				else:
					return False
			elif typeId == self.SURVEY:
				if firstInt is not None:
					if firstInt < 3:
						sms_util.sendMsg(user, keeper_strings.CONFIRM_MORNING_DIGEST_LIMITED_STATE_TEXT)
						user.digest_state = keeper_constants.DIGEST_STATE_LIMITED
						user.save()
					elif firstInt == 3:
						sms_util.sendMsg(user, keeper_strings.QUESTION_ACKNOWLEDGE_OK_RESPONSE_TEXT)
					else:
						sms_util.sendMsg(user, keeper_strings.QUESTION_ACKNOWLEDGE_GREAT_RESPONSE_TEXT)

					logger.info("User %s: Logging a score of %s for digest survey" % (user.id, firstInt))
					user.setStateData(keeper_constants.DIGEST_SURVEY_DATA_KEY, firstInt)
					analytics.logUserEvent(
						user,
						"Digest survey response",
						{"Score": firstInt}
					)
				else:
					return False
			elif typeId == self.DIGEST_CHANGE:
				logger.info("User %s: Updating digest time %s" % (user.id, chunk.originalText))

				return actions.updateDigestTime(user, chunk)
			elif typeId == self.REFERRAL:
				if user.signup_data_json:
					signupData = json.loads(user.signup_data_json)
				else:
					signupData = dict()

				if "referrer" in signupData and signupData["referrer"]:
					logger.error("User %s: I think I'm supposed to update referrer info with %s but %s is already there" % (user.id, chunk.originalText, signupData["referral"]))
				else:
					signupData["referrer"] = chunk.originalText
					user.signup_data_json = json.dumps(signupData)
					user.save()
					logger.info("User %s: Updated referrer to %s" % (user.id, chunk.originalText))

				sms_util.sendMsg(user, keeper_strings.RESPONSE_FOR_WHO_REFERRED_YOU)
		else:
			return False

		return True

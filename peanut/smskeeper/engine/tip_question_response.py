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

	def getScoreFunc(self, func):
		funcs = {self.SURVEY: self.surveyScore,
											self.NPS: self.npsScore,
											self.REFERRAL: self.referralScore,
											self.DIGEST_CHANGE: self.digestChangeScore}
		return funcs[func]

	# Returns back the score and which question type we think is the best match
	def getHighestScoreWithType(self, chunk, user):
		score = 0.0
		typeId = -1

		for x in self.TYPES:
			func = self.getScoreFunc(x)
			funcScore = func(chunk, user)

			if funcScore > score:
				score = funcScore
				typeId = x

		return score, typeId

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

	def getIntResponseScore(self, justNotified, chunk):
		score = 0.0
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
		return score

	def surveyScore(self, chunk, user):
		score = 0.0
		surveyJustNotified = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SURVEY, 2)
		npsJustNotified = user.wasRecentlySentMsgOfClass(tips.DIGEST_QUESTION_NPS_TIP_ID, 2)

		# nps comes after survey, so assume answer is most recent
		# hacky here
		if surveyJustNotified and not npsJustNotified:
			score = self.getIntResponseScore(surveyJustNotified, chunk)

		return score

	def npsScore(self, chunk, user):
		score = 0.0
		npsJustNotified = user.wasRecentlySentMsgOfClass(tips.DIGEST_QUESTION_NPS_TIP_ID, 2)
		if npsJustNotified:
			score = self.getIntResponseScore(npsJustNotified, chunk)
		return score

	def referralScore(self, chunk, user):
		score = 0.0
		if user.signup_data_json:
			signupData = json.loads(user.signup_data_json)
		else:
			signupData = "{}"

		referralAskJustNotified = user.wasRecentlySentMsgOfClass(tips.REFERRAL_ASK_TIP_ID, 2)
		if referralAskJustNotified:
			# Only score if we don't have any current referrer
			# So we don't score anything on the second message
			if "referrer" not in signupData or len(signupData["referrer"]) == 0:
				score = .6

		return score

	def digestChangeScore(self, chunk, user):
		score = 0.0

		chunkFeatures = chunk_features.ChunkFeatures(chunk, user)

		# things that match this RE will get a minus
		containsReminderWord = chunkFeatures.hasCreateWord()
		beginsWithReminderWord = chunkFeatures.beginsWithCreateWord()

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

	def getScore(self, chunk, user):
		score = 0.0

		chunkFeatures = chunk_features.ChunkFeatures(chunk, user)

		score, typeId = self.getHighestScoreWithType(chunk, user)

		# none of our questions ask for a phone number at the moment, and this could conflict with resolve handle
		if chunkFeatures.hasPhoneNumber():
			score -= 0.5

		return score

	def execute(self, chunk, user):
		score, typeId = self.getHighestScoreWithType(chunk, user)

		firstInt = self.getFirstInt(chunk)

		if score > 0:
			if typeId == self.NPS:
				if firstInt is not None:
					if firstInt < 8:
						sms_util.sendMsg(user, keeper_strings.QUESTION_ACKNOWLEDGE_OK_RESPONSE_TEXT)
					else:
						sms_util.sendMsg(user, keeper_strings.QUESTION_ACKNOWLEDGE_GREAT_RESPONSE_TEXT)

					logger.info("User %s: Logging a score of %s for nps" % (user.id, firstInt))
					user.setStateData("nps-result", firstInt)
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
					user.setStateData("digest-survey-result", firstInt)
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
				signupData = json.loads(user.signup_data_json)

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

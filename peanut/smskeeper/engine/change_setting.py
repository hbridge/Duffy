import re
import string

from smskeeper import sms_util, msg_util, helper_util, actions
from smskeeper import keeper_constants, keeper_strings
from smskeeper import analytics
from .action import Action
from smskeeper.chunk_features import ChunkFeatures


class ChangeSettingAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_CHANGE_SETTING
	summaryRegex = re.compile(r"(daily|morning) summary", re.I)

	def getScore(self, chunk, user):
		score = 0.0
		features = ChunkFeatures(chunk, user)

		normalizedText = chunk.normalizedText()
		if self.looksLikeTip(features, user):
			score = 1.0

		if features.containsPostalCode():
			if features.containsZipCodeWord():
				score = .9
			else:
				score = .6

		if msg_util.nameInSetName(normalizedText, tutorial=False):
			score = .9

		if chunk.contains(self.summaryRegex):
			if "never" in chunk.normalizedText() or chunk.getNattyResult(user):
				score = .95

		if not user.isTutorialComplete():
			score = 0

		return score

	def execute(self, chunk, user):
		features = ChunkFeatures(chunk, user)

		if self.looksLikeTip(features, user):
			self.setTipFrequency(user, features)

		elif features.containsPostalCode():
			self.setPostalCode(user, chunk.originalText)

		elif msg_util.nameInSetName(chunk.originalText, tutorial=False):
			name = msg_util.nameInSetName(chunk.originalText, tutorial=False)
			self.setName(user, name)

		elif chunk.contains(self.summaryRegex):
			return actions.updateDigestTime(user, chunk)

		return True

	def looksLikeTip(self, features, user):
		if features.containsTipWord():
			if features.containsNegativeWord() or max(features.recurScores().values()) > 0.5:
				return True
		return False

	def setTipFrequency(self, user, features):
		old_tip_frequency = user.tip_frequency_days
		if features.containsNegativeWord():
			user.tip_frequency_days = 0
			user.save()
			sms_util.sendMsg(user, keeper_strings.TIP_STOP_CONFIRMATION_TEXT)
		else:
			recurType, bestScore = features.recurScores().items()[0]
			if recurType == keeper_constants.RECUR_WEEKLY:
				user.tip_frequency_days = 7
				user.save()
				sms_util.sendMsg(user, keeper_strings.TIP_WEEKLY_CONFIRMATION_TEXT)
			elif recurType == keeper_constants.RECUR_MONTHLY:
				user.tip_frequency_days = 30
				user.save()
				sms_util.sendMsg(user, keeper_strings.TIP_MONTHLY_CONFIRMATION_TEXT)
			elif recurType == keeper_constants.RECUR_DAILY:
				user.tip_frequency_days = 1
				user.save()
				sms_util.sendMsg(user, keeper_strings.TIP_DAILY_CONFIRMATION_TEXT)
			else:
				sms_util.sendMsg(user, keeper_strings.TIP_FREQUENCY_CHANGE_ERROR_TEXT)

		analytics.logUserEvent(
			user,
			"Changed Tip Frequency",
			{
				"Old Frequency": old_tip_frequency,
				"New Frequency": user.tip_frequency_days,
			}
		)

	def setName(self, user, name):
		name = name.strip(string.punctuation)
		if name and name != "":
			user.name = name
			user.save()
			sms_util.sendMsg(user, keeper_strings.NAME_CHANGE_CONFIRMATION_TEXT % name)
		else:
			sms_util.sendMsg(user, keeper_strings.NAME_CHANGE_ERROR_TEXT)
		analytics.logUserEvent(
			user,
			"Changed Name",
			None
		)

	def setPostalCode(self, user, msg):
		postalCode = msg_util.getPostalCode(msg)

		if postalCode is None:
			sms_util.sendMsg(user, keeper_strings.ZIPCODE_CHANGE_ERROR_TEXT)
			return True

		user.postal_code = postalCode
		timezone, wxcode, tempFormat = msg_util.dataForPostalCode(postalCode)
		user.timezone = timezone
		user.wxcode = wxcode
		user.temp_format = tempFormat
		user.save()
		sms_util.sendMsg(user, helper_util.randomAcknowledgement())

		analytics.logUserEvent(
			user,
			"Changed PostalCode",
			None
		)

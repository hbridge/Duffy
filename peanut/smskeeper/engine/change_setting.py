import re
import string

from smskeeper import sms_util, msg_util, helper_util, actions
from smskeeper import keeper_constants
from smskeeper import analytics
from .action import Action
from smskeeper.chunk_features import ChunkFeatures


class ChangeSettingAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_CHANGE_SETTING

	zipRegex = re.compile(r"my zip ?code is (\d{5}(\-\d{4})?)", re.I)

	summaryRegex = re.compile(r"(daily|morning) summary", re.I)

	def getScore(self, chunk, user):
		score = 0.0
		features = ChunkFeatures(chunk, user)

		normalizedText = chunk.normalizedText()
		if self.looksLikeTip(features, user):
			score = .9

		if self.zipRegex.match(normalizedText) is not None:
			score = .9

		if msg_util.nameInSetName(normalizedText, tutorial=False):
			score = .9

		if chunk.contains(self.summaryRegex):
			if "never" in chunk.normalizedText() or chunk.getNattyResult(user):
				score = .95

		if not user.isTutorialComplete():
			score = 0

		return score

	def execute(self, chunk, user):
		normalizedText = chunk.normalizedText()
		features = ChunkFeatures(chunk, user)

		if self.looksLikeTip(features, user):
			self.setTipFrequency(user, features)

		elif self.zipRegex.match(normalizedText) is not None:
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
			sms_util.sendMsg(user, "Ok, I'll stop sending you tips.")
		else:
			recurType, bestScore = features.recurScores().items()[0]
			if recurType == keeper_constants.RECUR_WEEKLY:
				user.tip_frequency_days = 7
				user.save()
				sms_util.sendMsg(user, "Ok, I'll send you tips weekly.")
			elif recurType == keeper_constants.RECUR_MONTHLY:
				user.tip_frequency_days = 30
				user.save()
				sms_util.sendMsg(user, "Ok, I'll send you tips monthly.")
			elif recurType == keeper_constants.RECUR_DAILY:
				user.tip_frequency_days = 1
				user.save()
				sms_util.sendMsg(user, "Ok, I'll send you tips daily.")
			else:
				sms_util.sendMsg(user, "Sorry, I didn't get that. You can type 'send me tips weekly/monthly/never' to change how often I send you tips.")

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
			sms_util.sendMsg(user, "Great, I'll call you %s from now on." % name)
		else:
			sms_util.sendMsg(user, "Sorry, I didn't catch that, try saying something like 'My name is Keeper'" % name)
		analytics.logUserEvent(
			user,
			"Changed Name",
			None
		)

	def setPostalCode(self, user, msg):
		postalCode = msg_util.getPostalCode(msg)

		if postalCode is None:
			sms_util.sendMsg(user, "I'm sorry, I don't know that postal code")
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




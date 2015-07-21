import re
import string

from smskeeper import sms_util, msg_util, helper_util
from smskeeper import keeper_constants
from smskeeper import analytics
from .action import Action


class ChangeSettingAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_CHANGE_SETTING

	tipRegex = re.compile(r'.*send me tips', re.I)

	zipRegex = re.compile(r"my zip ?code is (\d{5}(\-\d{4})?)", re.I)

	def getScore(self, chunk, user):
		score = 0.0

		normalizedText = chunk.normalizedText()
		if self.tipRegex.match(normalizedText) is not None:
			score = .9

		if self.zipRegex.match(normalizedText) is not None:
			score = .9

		if msg_util.nameInSetName(normalizedText, tutorial=False):
			score = .9

		return score

	def execute(self, chunk, user):
		normalizedText = chunk.normalizedText()

		if self.tipRegex.match(normalizedText) is not None:
			self.setTipFrequency(user, chunk.originalText)

		if self.zipRegex.match(normalizedText) is not None:
			self.setPostalCode(user, chunk.originalText)

		if msg_util.nameInSetName(chunk.originalText, tutorial=False):
			name = msg_util.nameInSetName(chunk.originalText, tutorial=False)
			self.setName(user, name)

	def setTipFrequency(self, user, msg):
		old_tip_frequency = user.tip_frequency_days
		if "weekly" in msg:
			user.tip_frequency_days = 7
			user.save()
			sms_util.sendMsg(user, "Ok, I'll send you tips weekly.")
		elif "monthly" in msg:
			user.tip_frequency_days = 30
			user.save()
			sms_util.sendMsg(user, "Ok, I'll send you tips monthly.")
		elif "daily" in msg:
			user.tip_frequency_days = 1
			user.save()
			sms_util.sendMsg(user, "Ok, I'll send you tips daily.")
		elif "never" in msg or "stop" in msg or "don't" in msg:
			user.tip_frequency_days = 0
			user.save()
			sms_util.sendMsg(user, "Ok, I'll stop sending you tips.")
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
		timezone, wxcode = msg_util.dataForPostalCode(postalCode)
		user.timezone = timezone
		user.wxcode = wxcode
		user.save()
		sms_util.sendMsg(user, helper_util.randomAcknowledgement())

		analytics.logUserEvent(
			user,
			"Changed PostalCode",
			None
		)




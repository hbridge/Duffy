import string
import re

from common import natty_util

punctuationWhitelist = '-'

class Chunk:
	originalText = None
	commandWords = []
	nattyResult = None

	def __init__(self, originalText):
		self.originalText = originalText

	def contractedText(self):
		return ""

	def normalizedText(self):
		return self.normalizeText(self.originalText)

	def normalizeText(self, text, charsToStrip=string.punctuation):
		newMsg = ''.join(ch for ch in text if ch.isalnum() or ch == ' ' or ch in punctuationWhitelist)
		newMsg = newMsg.strip().lower()
		return newMsg

	def normalizedTextWithoutTiming(self, user):
		nattyResult = self.getNattyResult(user)
		if nattyResult:
			return self.normalizeText(nattyResult.queryWithoutTiming)
		else:
			return self.normalizeText(self.originalText)

	def getNattyResult(self, user):
		if not self.nattyResult:
			self.nattyResult = natty_util.getNattyResult(self.originalText, user)
		return self.nattyResult

	def matches(self, regex):
		normalizedText = self.normalizeText(self.originalText)
		return re.match(regex, normalizedText) is not None

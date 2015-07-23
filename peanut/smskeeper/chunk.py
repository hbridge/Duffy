import string

from common import natty_util


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

	def normalizeText(self, text):
		newMsg = ''.join(ch for ch in text if ch.isalnum() or ch == ' ')
		newMsg = newMsg.strip(string.punctuation).strip().lower()
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

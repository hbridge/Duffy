import string

from common import natty_util


class Chunk:
	originalText = None
	commandWords = []
	NattyResult = None

	def __init__(self, originalText):
		self.originalText = originalText

	def contractedText(self):
		return ""

	def normalizedText(self):
		newMsg = ''.join(ch for ch in self.originalText if ch.isalnum() or ch == ' ')
		newMsg = newMsg.strip(string.punctuation).strip().lower()
		return newMsg

	def getNattyResult(self, user):
		return natty_util.getNattyResult(self.originalText, user)

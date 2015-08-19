import string
import re

from common import natty_util

punctuationWhitelist = '-'


class Chunk:
	originalText = None
	commandWords = []
	nattyResult = None
	isPartOfMultiChunk = False
	lineNum = 0

	def __init__(self, originalText, isPartOfMultiChunk=False, lineNum=0):
		self.originalText = originalText

		if isPartOfMultiChunk:
			self.isPartOfMultiChunk = isPartOfMultiChunk
			self.lineNum = lineNum

	def contractedText(self):
		return ""

	def normalizedText(self):
		return self.normalizeText(self.originalText)

	def normalizeText(self, text, charsToStrip=string.punctuation):
		newMsg = text.strip().lower()

		# Terrible HACK - this should be somewhere else
		# problem is, next line we clear out punctuation so need to do a replace before then
		newMsg = newMsg.replace("w/", "with ")

		newMsg = ''.join(ch for ch in newMsg if ch.isalnum() or ch == ' ' or ch in punctuationWhitelist)
		newMsg = newMsg.strip()
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

	def contains(self, regex):
		normalizedText = self.normalizeText(self.originalText)
		return re.search(regex, normalizedText) is not None

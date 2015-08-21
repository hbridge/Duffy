import string
import re

from common import natty_util

punctuationWhitelist = '-'

RELATIONSHIP_RE = re.compile(r'(mom|dad|wife|husband|boyfriend|girlfriend|spouse|partner|mother|father)', re.I)
RELATIONSHIP_SUBJECT_DELIMETERS = re.compile(r'to|on|at|in|by|about', re.I)

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

	def normalizeText(self, text, charsToStrip=string.punctuation, lowercase=True):
		newMsg = text.strip()
		if lowercase:
			newMsg = newMsg.lower()

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

	def handles(self):
		handles = []
		words = self.normalizeText(self.originalText, lowercase=False).split(' ')
		subjectDelimiterIndices = []

		for idx, word in enumerate(words):
			if RELATIONSHIP_SUBJECT_DELIMETERS.match(word):
				subjectDelimiterIndices.append(idx)
				continue

		for idx, word in enumerate(words):
			if word[0].isupper() or RELATIONSHIP_RE.match(word):
				if idx == 0:
					continue  # don't support putting a handle first
				if re.match(r"Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday", word):
					continue
				if len(words) > idx + 1:
					if len(subjectDelimiterIndices) > 0:
						# require that there is some kind of subject delimeter, and that the handle
						# is before the first one, meaning its the direct object of the sentence, not
						# the indirect object
						if subjectDelimiterIndices[0] > idx:
							handles.append(word)
		return handles

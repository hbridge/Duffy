import string
import re
import phonenumbers

from common import natty_util

punctuationWhitelist = '-'

RELATIONSHIP_RE = re.compile(r'(mom|dad|wife|husband|boyfriend|girlfriend|spouse|partner|mother|father)', re.I)
RELATIONSHIP_SUBJECT_DELIMETERS = re.compile(r'to|on|at|in|by|about', re.I)
HANDLE_BLACKLIST = re.compile(r'you|remind|me|I|im|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday', re.I)

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

	def __str__(self):
		return self.originalText

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
		numWordsStartUpper = 0

		for idx, word in enumerate(words):
			if RELATIONSHIP_SUBJECT_DELIMETERS.match(word):
				subjectDelimiterIndices.append(idx)
				continue
			if len(word) > 0 and word[0].isupper():
				numWordsStartUpper += 1

		# we get some messages from people where very word is capped
		useCapitalizationSignal = (numWordsStartUpper < len(words) / 2.0)

		for idx, word in enumerate(words):
			if len(word) == 0:
				continue
			if RELATIONSHIP_RE.match(word) or (word[0].isupper() and useCapitalizationSignal):
				if idx == 0:
					continue  # don't support putting a handle first
				if HANDLE_BLACKLIST.match(word):
					continue
				if len(words) > idx + 1:
					if len(subjectDelimiterIndices) > 0:
						# require that there is some kind of subject delimeter, and that the handle
						# is before the first one, meaning its the direct object of the sentence, not
						# the indirect object
						if subjectDelimiterIndices[0] > idx:
							handles.append(word)
		return handles

	def extractPhoneNumbers(self):
		matches = phonenumbers.PhoneNumberMatcher(self.originalText, 'US')
		remaining_str = unicode(self.originalText)
		phone_numbers = []
		for match in matches:
			formatted = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)
			if formatted:
				phone_numbers.append(formatted)
				remaining_str = remaining_str.replace(match.raw_string, "")

		return phone_numbers, remaining_str

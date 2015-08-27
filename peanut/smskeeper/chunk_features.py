from smskeeper import msg_util, entry_util
import phonenumbers
from smskeeper import keeper_constants
from smskeeper import msg_util


class ChunkFeatures:
	chunk = None
	user = None

	def __init__(self, chunk, user):
		self.chunk = chunk
		self.user = user

	# things that match this RE will get a boost for done
	beginsWithDoneWordRegex = r'^(done|check off) '

	# NOTE: Make sure there's a space after these words, otherwise "printed" will match
	# things that match this RE will get a boost for create
	createWordRegex = "(remind|buy|print|fax|go|get|study|wake|fix|make|schedule|fill|find|clean|pick up|cut|renew|fold|mop|pack|pay|call)"
	beginsWithCreateWordRegex = r'^%s ' % createWordRegex
	containsCreateWordhRegex = r'%s ' % createWordRegex

	weatherRegex = r"\b(weather|forecast|rain|temp|temperature|how hot)\b"

	# Features
	def hasTimingInfo(self):
		if self.chunk.getNattyResult(self.user):
			return True
		return False

	def hasTimeOfDay(self):
		nattyResult = self.chunk.getNattyResult(self.user)
		if nattyResult and nattyResult.hadTime:
			return True
		return False

	def numInterestingWords(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		return len(msg_util.getInterestingWords(cleanedText))

	def hasDoneWord(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	def beginsWithDoneWord(self):
		return self.chunk.matches(self.beginsWithDoneWordRegex)

	def beginsWithNo(self):
		return msg_util.startsWithNo(self.chunk.normalizedText())

	def numMatchingEntriesStrict(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		interestingWords = msg_util.getInterestingWords(cleanedText)
		return len(entry_util.fuzzyMatchEntries(self.user, ' '.join(interestingWords), 80))

	def hasCreateWord(self):
		return self.chunk.contains(self.containsCreateWordhRegex)

	def beginsWithCreateWord(self):
		return self.chunk.matches(self.beginsWithCreateWordRegex)

	def hasPhoneNumber(self):
		matches = phonenumbers.PhoneNumberMatcher(self.chunk.originalText, 'US')
		return matches.has_next()

	def isPhoneNumber(self):
		matches = phonenumbers.PhoneNumberMatcher(self.chunk.originalText, 'US')
		if not matches.has_next():
			return False
		match = matches.next()
		return match.start == 0 and match.end == len(self.originalText)

		return matches.has_next()

	# is the primary verb of the chunk "remind" as in "remind me to poop"
	# as opposed to "call fred tonight"
	def primaryActionIsRemind(self):
		return self.chunk.matches(keeper_constants.SHARED_REMINDER_VERB_WHITELIST_REGEX)

	def hasWeatherWord(self):
		return self.chunk.contains(self.weatherRegex)

	def isQuestion(self):
		isQuestion = False
		if self.chunk.endsWith("\?", punctuationWhitelist="?"):
			isQuestion = True

		if self.chunk.matches(r'what|where|when|how|why|who|which'):
			isQuestion = True

		return isQuestion

	def isBroadQuestion(self):
		return self.chunk.matches(r'where\b|how\b|why\b|who\b')

	def hasFetchDigestWords(self):
		if self.chunk.contains(r'tasks|to ?do|reminders|list'):
			return True
		return False

	def couldBeDone(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	def containsToday(self):
		return self.chunk.contains('today')

	def containsDeleteWord(self):
		return self.chunk.contains(r'delete|clear|remove')

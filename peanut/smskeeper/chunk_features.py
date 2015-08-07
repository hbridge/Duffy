from smskeeper import msg_util, entry_util


class ChunkFeatures:
	chunk = None
	user = None

	def __init__(self, chunk, user):
		self.chunk = chunk
		self.user = user

	# things that match this RE will get a boost for create
	# NOTE: Make sure there's a space after these words, otherwise "printed" will match
	beginsWithDoneWordRegex = r'^(done|check off) '

	# Features
	def hasTimingInfo(self):
		if self.chunk.getNattyResult(self.user):
			return True
		return False

	def numInterestingWords(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		return len(msg_util.getInterestingWords(cleanedText))

	def hasDoneWord(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	def beginsWithDoneWord(self):
		return self.chunk.matches(self.beginsWithDoneWordRegex)

	def numMatchingEntriesStrict(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		interestingWords = msg_util.getInterestingWords(cleanedText)
		return len(entry_util.fuzzyMatchEntries(self.user, ' '.join(interestingWords), 80))

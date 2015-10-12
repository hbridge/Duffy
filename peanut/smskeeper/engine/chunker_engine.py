import re
from smskeeper.chunk import Chunk

wordRe = re.compile(r'[^ \n^]+')


class ChunkerEngine:
	message = None

	def __init__(self, message):
		self.message = message

	def getChunks(self):
		chunk = Chunk(self.message.body)
		return chunk

	def segments(self):
		segments = []
		wordIter = wordRe.finditer(self.message)
		lastSegmentStart = 0
		for word in wordIter:
			wordFeatures = WordFeatures(word.start(), self.message)
			if wordFeatures.isFirstWordInSentence() and word.start() != 0:
				segments.append({"start": lastSegmentStart, "end": word.start()})
				lastSegmentStart = word.start()
		segments.append({"start": lastSegmentStart, "end": len(self.message)})
		return segments

	def getChunkStartIndices(self):
		return map(lambda segment: segment["start"], self.segments())


class WordFeatures:
	word = None
	containingString = None
	location = None

	def __init__(self, location, string):
		self.location = location
		self.containingString = string
		match = wordRe.match(string[location:])
		self.word = string[location:(location + match.end())]

	def isFirstWordInSentence(self):
		# print "isFirstWordInSentence: %d %s %s" % (self.location, self.word, self.containingString)
		if self.location == 0:
			return True
		beforeWord = self.containingString[:self.location]
		reversedStr = beforeWord[::-1]
		return re.match(r'\W+[.]', reversedStr) is not None

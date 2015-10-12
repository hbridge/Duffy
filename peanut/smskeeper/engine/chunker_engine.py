import re
from smskeeper.chunk import Chunk

wordRe = re.compile(r'[^ \n^]+')
MIN_BOUNDARY_SCORE = 0.5


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
			if word.start() == 0:
				continue
			if self.segmentBoundaryScore(self.message[word.start():word.end()], word.start()):
				segments.append({"start": lastSegmentStart, "end": word.start()})
				lastSegmentStart = word.start()
		segments.append({"start": lastSegmentStart, "end": len(self.message)})
		return segments

	def segmentBoundaryScore(self, word, wordLocation):
		wordFeatures = WordFeatures(word, wordLocation, self.message)

		scoreVector = []
		scoreVector.append(1.0 if wordFeatures.isFirstWordInSentence() else 0.0)

		return sum(scoreVector)

	def getChunkStartIndices(self):
		return map(lambda segment: segment["start"], self.segments())


class WordFeatures:
	word = None
	containingString = None
	location = None

	def __init__(self, word, location, string):
		self.location = location
		self.containingString = string
		self.word = word

	def isFirstWordInSentence(self):
		# print "isFirstWordInSentence: %d %s %s" % (self.location, self.word, self.containingString)
		if self.location == 0:
			return True
		beforeWord = self.containingString[:self.location]
		reversedStr = beforeWord[::-1]
		return re.match(r'\W+[.]', reversedStr) is not None

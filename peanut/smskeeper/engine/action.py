from smskeeper.models import Message
from smskeeper.chunk import Chunk


class Action:
	ACTION_CLASS = None

	def __init__(self):
		if self.ACTION_CLASS is None:
			raise NameError("ActionClass must not be None")

	def getScore(self, chunk, user):
		raise NameError("Abstract")

	def execute(self, chunk, user):
		raise NameError("Abstract")

	# TODO this is a hack, going off historical messages for now
	@classmethod
	def HasHistoricalMatchForChunk(cls, chunk, overrideClass=None):
		if not cls.ACTION_CLASS:
			raise NameError("%s has no ACTION_CLASS" % cls)
		if overrideClass:
			className = overrideClass
		else:
			className = cls.ACTION_CLASS
		pastMessages = Message.getClassifiedAs(className)
		for pastMsg in pastMessages:
			# hack confusing messages for chunks
			pastChunk = Chunk(pastMsg.getBody())
			if chunk.normalizedText() == pastChunk.normalizedText():
				return True

		return False

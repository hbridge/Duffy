import re
import random
from smskeeper import msg_util
from smskeeper import keeper_constants


class Nicety():
	reStr = None
	responses = None

	def __init__(self, reStr, responses):
		self.reStr = reStr
		self.responses = responses

	def matchesMsg(self, msg):
		cleanedMsg = msg_util.cleanMsgText(msg)
		return re.match(self.reStr, cleanedMsg, re.I) is not None

	def getResponse(self):
		if not self.responses or len(self.responses) == 0:
			return None
		return random.choice(self.responses)


SMSKEEPER_NICETIES = [
	Nicety("hi|hello|hey", ["Hi there."]),
	Nicety("thanks|thank you|many thanks|thanks keeper|thank you keeper|great thanks", ["You're welcome."]),
	Nicety("no thanks|not now", None),
	Nicety("yes|no|y|n", None),
	Nicety("cool|ok|great", None),
]


def getNicety(msg):
	for nicety in SMSKEEPER_NICETIES:
		if (nicety.matchesMsg(msg)):
			return nicety
	return None

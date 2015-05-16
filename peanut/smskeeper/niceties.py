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
	Nicety("hi$|hello|hey", ["Hi there."]),
	Nicety(
		"thanks|thank you|many thanks|thanks keeper|thank you keeper|great thanks",
		["You're welcome.", "Happy to help.", "No problem.", "Sure thing."]
	),
	Nicety("no thanks|not now", None),
	Nicety("yes$|no$|y$|n$", None),
	Nicety("cool$|ok$|great$", None),
	Nicety(
		"how are you|how're you|hows it going|how are you today",
		["I'm good, thanks for asking!", "Can't complain!"]
	),
	Nicety(
		"i hate you|you suck|this is stupid|youre stupid",
		["Well that's not very nice.", "I'm doing my best."]
	),
	Nicety(
		"whats your name|who are you|what do you call yourself",
		["Keeper!"]
	),
	Nicety(
		"tell me a joke",
		["I don't think you'd appreciate my humor."]
	),
	Nicety(
		"i love you|youre pretty (cool|neat)",
		["You're pretty cool too!"]
	),
]


def getNicety(msg):
	for nicety in SMSKEEPER_NICETIES:
		if (nicety.matchesMsg(msg)):
			return nicety
	return None

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
		".*thanks( keeper)?|.*thank you( (very|so) much)?( keeper)?",
		["You're welcome.", "Happy to help.", "No problem.", "Sure thing."]
	),
	Nicety("no thanks|not now|maybe later|great to meet you too|nice to meet you too", None),
	Nicety("yes$|no$|y$|n$|nope$", None),
	Nicety("cool$|ok$|great$|k$|sweet$|hah(a)?|lol$|okay$", None),
	Nicety(
		"how are you( today)?|how're you|hows it going",
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
		"i love you|youre (pretty )?(cool|neat|smart)",
		[u"You're pretty cool too! \U0001F60E"]
	),
	Nicety(
		"hows the weather|whats the weather",
		[u"It's always sunny in cyberspace \U0001F31E"]
	),
	Nicety(
		"I(m| am) sorry|apologies|I apologize|sry",
		[u"That's ok.", "Don't worry about it.", "No worries.", "I'm over it."]
	),
	Nicety(
		"thats all( for now)?",
		["Ok, I'm here if you need me."]
	),
	Nicety(
		"are you( a)? real( person)?|are you human|are you an? (computer|machine)|are you an ai",
		["Do you think I am?"]
	)
]


def getNicety(msg):
	for nicety in SMSKEEPER_NICETIES:
		if (nicety.matchesMsg(msg)):
			return nicety
	return None

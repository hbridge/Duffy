import re
import random
from smskeeper import msg_util


class Nicety():
	reStr = None
	responses = None

	def __init__(self, reStr, responses, customRenderer=None):
		self.reStr = reStr
		self.responses = responses
		self.customRenderer = customRenderer

	def matchesMsg(self, msg):
		cleanedMsg = msg_util.cleanMsgText(msg)
		return re.match(self.reStr, cleanedMsg, re.I) is not None

	def getResponse(self, user, requestDict, keeperNumber):
		if self.customRenderer:
			return self.customRenderer(user, requestDict, keeperNumber)
		if not self.responses or len(self.responses) == 0:
			return None
		return random.choice(self.responses)

	def __str__(self):
		string = "%s %s %s" % (self.reStr, self.responses, self.customRenderer)
		return string.encode('utf-8')


SMSKEEPER_NICETIES = [
	Nicety("hi$|hello|hey", ["Hi there."]),
	Nicety("no thanks|not now|maybe later|great to meet you too|nice to meet you too", None),
	Nicety("yes$|no$|y$|n$|nope$", None),
	Nicety(u"cool$|ok$|great$|k$|sweet$|hah(a)?|lol$|okay$|awesome|\U0001F44D", None),
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
	),
	Nicety(
		"whats the meaning of life",
		["42"]
	)
]


def getNicety(msg):
	for nicety in SMSKEEPER_NICETIES:
		if (nicety.matchesMsg(msg)):
			return nicety
	return None

'''
Custom niceities
These don't just return a string, but can render text conditional on the user, request and keeperNumber
'''

def custom_nicety_for(regexp):
	def gethandler(f):
		nicety = Nicety(regexp, None, f)
		SMSKEEPER_NICETIES.append(nicety)
		return f
	return gethandler

@custom_nicety_for(r'.*thanks( keeper)?|.*thank you( (very|so) much)?( keeper)?|ty($| keeper)?')
def renderThankYouResponse(user, requestDict, keeperNumber):
	return random.choice(["You're welcome.", "Happy to help.", "No problem.", "Sure thing."])

# for nicety in SMSKEEPER_NICETIES:
# 	print nicety

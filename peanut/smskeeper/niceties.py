from datetime import datetime, timedelta
from smskeeper import time_utils
import random
import re

import pytz
from smskeeper import keeper_constants
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
	),
	Nicety(
		"where (are you from|do you live)",
		[u"I was created is NYC \U0001f34e"]
	),
	Nicety(
		"is this (a scam|for real)",
		[u"I'm just a friendly digital assistant here to help you remember things."]
	),
	Nicety(
		"(is this|are you)( kind of|kinda)? like siri",
		[u"We're distantly related. I text and throw better parties though! \U0001f389"]
	),
	Nicety(
		"what do you think of siri",
		[u"She's a nice lady, but she needs to loosen up! \U0001f60e"]
	),
	Nicety(
		"why.* my zip( )?code",
		[u"Knowing your zip code allows me to send you reminders in the right time zone."]
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

@custom_nicety_for(r'.*thanks( keeper)?|.*thank you( (very|so) much)?( keeper)?|(ty|thx|thz|thks)($| keeper)?')
def renderThankYouResponse(user, requestDict, keeperNumber):
	base = random.choice(["You're welcome.", "Happy to help.", "No problem.", "Sure thing."])
	if time_utils.isDateOlderThan(user.last_share_upsell, keeper_constants.SHARE_UPSELL_FREQUENCY_DAYS):
		user.last_share_upsell = datetime.now(pytz.utc)
		user.save()
		return "%s %s %s!" % (base, keeper_constants.SHARE_UPSELL_PHRASE, user.getInviteUrl())
	else:
		return base


# for nicety in SMSKEEPER_NICETIES:
# 	print nicety

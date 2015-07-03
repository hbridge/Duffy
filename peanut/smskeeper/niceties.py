import datetime
from smskeeper import time_utils
import random
import re

import pytz
from smskeeper import keeper_constants
from smskeeper import msg_util
import humanize
import emoji


class Nicety():
	reStr = None
	responses = None

	def __init__(self, reStr, responses, customRenderer=None):
		self.reStr = reStr
		self.responses = responses
		self.customRenderer = customRenderer

	def matchesMsg(self, msg):
		if not msg or msg == "":
			return False
		cleanedMsg = msg_util.cleanMsgText(msg)
		try:
			return re.match(self.reStr, cleanedMsg, re.I) is not None
		except:
			print "RE raised exception: %s", self.reStr

	def getResponse(self, user, requestDict, keeperNumber):
		response = None

		if self.customRenderer:
			response = self.customRenderer(user, requestDict, keeperNumber)
		elif self.responses and len(self.responses) > 0:
			response = random.choice(self.responses)

		return response

	def __str__(self):
		string = "%s %s %s" % (self.reStr, self.responses, self.customRenderer)
		return string.encode('utf-8')


SMSKEEPER_NICETIES = [
	Nicety("hi$|hello|hey", ["Hi there."]),
	Nicety("no thanks|not now|maybe later|great to meet you too|nice to meet you too", None),
	Nicety("yes$|no$|y$|n$|nope$", None),
	Nicety(u"cool$|ok$|great$|k+$|sweet$|hah(a)?|lol$|okay$|(thats )?awesome|\U0001F44D", None),
	Nicety(
		"how are you( today)?|how're you|hows it going",
		[u"I'm good, thanks for asking! \U0001F603", u"Can't complain! \U0001F603"]
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
		[u"I don't think you'd appreciate my humor. \U0001F609"]
	),
	Nicety(
		"i love you|youre (pretty )?(cool|neat|smart)|youre the (best|greatest)",
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
		"thats all( for now)?$|see you later$|i have to go$",
		[u"Ok, I'm here if you need me! \U0001F603"]
	),
	Nicety(
		"are you( a)? real( person)?|are you human|are you an? (computer|machine)|are you an ai",
		["Do you think I am?"]
	),
	Nicety(
		"whats the meaning of life",
		[u"42 \U0001F433"]
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
	),
	Nicety(
		"will do|I will|sure",
		[u"\U0001F44F", u"\U0001F44D"]
	),
	Nicety(
		"bye(bye)?|keep in touch",
		[u"\U0001F44B See ya! Lmk if you need anything!"]
	),
	Nicety(
		"done$|did it",
		[":thumbsup:", u"Nice!", u"Sweet!", ":party_popper:"]
	),
	Nicety(
		"have a(n)? [\w]+ day",
		["Thanks, you too! :smile:"]
	),
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


@custom_nicety_for(r'.*thanks( keeper)?|.*thank (you|u)( (very|so) much)?( keeper)?|(ok )?(ty|thx|thz|thks|thnx|thanx)( keeper)?$')
def renderThankYouResponse(user, requestDict, keeperNumber):
	base = random.choice(["You're welcome.", "Happy to help.", "No problem.", "Sure thing."])
	if time_utils.isDateOlderThan(user.last_feedback_prompt, keeper_constants.FEEDBACK_FREQUENCY_DAYS) and user.activated < datetime.datetime.now(pytz.utc) - datetime.timedelta(days=keeper_constants.FEEDBACK_MIN_ACTIVATED_TIME_IN_DAYS):
		user.last_feedback_prompt = datetime.datetime.now(pytz.utc)
		user.save()
		return "%s %s" % (base, keeper_constants.FEEDBACK_PHRASE)
	elif time_utils.isDateOlderThan(user.last_share_upsell, keeper_constants.SHARE_UPSELL_FREQUENCY_DAYS):
		user.last_share_upsell = datetime.datetime.now(pytz.utc)
		user.save()
		return "%s %s %s!" % (base, keeper_constants.SHARE_UPSELL_PHRASE, user.getInviteUrl())
	else:
		return base


@custom_nicety_for(r'how old are you|whats your birthday|when were you born')
def renderBirthdayInquiry(user, requestDict, keeperNumber):
	delta = datetime.date.today() - keeper_constants.KEEPER_BIRTHDAY
	deltaText = humanize.naturaldelta(delta)
	return u"I was born on April 29th, 2015. That makes me about %s old! \U0001F423" % (deltaText)


EMOJI_NICETY_RE = u'([\U00002600-\U000027BF])|([\U0001f300-\U0001f64F])|([\U0001f680-\U0001f6FF])'
try:
	re.compile(EMOJI_NICETY_RE)
except:
	EMOJI_NICETY_RE = (u'([\u2600-\u27BF])|([\uD83C][\uDF00-\uDFFF])|([\uD83D][\uDC00-\uDE4F])|([\uD83D][\uDE80-\uDEFF])')


@custom_nicety_for(EMOJI_NICETY_RE)
def renderRandomEmoji(user, requestDict, keeperNumber):
	return random.choice(emoji.EMOJI_UNICODE.values())

# for nicety in SMSKEEPER_NICETIES:
# 	print nicety

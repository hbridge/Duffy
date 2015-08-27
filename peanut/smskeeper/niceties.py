import datetime
import humanize
import emoji
import random
import re
import pytz
import logging
import phonenumbers

from smskeeper import keeper_constants
from smskeeper import msg_util
from smskeeper import time_utils

from common import date_util

logger = logging.getLogger(__name__)


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

	def isSilent(self):
		return (self.responses is None and self.customRenderer is None)

	def __str__(self):
		string = "%s %s %s" % (self.reStr, self.responses, self.customRenderer)
		return string.encode('utf-8')


SMSKEEPER_NICETIES = [
	Nicety("hi$|hello( keeper)?$|hey( keeper)?$", ["Hi there."]),
	Nicety("no thanks|not now|maybe later|great to meet you too|nice to meet you too", None),
	Nicety("yes( [\w]+)?$|no$|y$|n$|nope$", None),
	Nicety(u"cool$|ok$|great$|k+$|sweet$|hah(a)?|lol$|okay$|(thats )?awesome|\U0001F44D", None),
	Nicety(
		"me too|i agree|agreed|i have a question",
		None
	),
	Nicety(
		".*how are you( today)?|how're you|hows it going",
		[u"I'm good, thanks for asking! \U0001F603", u"Can't complain! \U0001F603"]
	),
	Nicety(
		"i hate you|you suck|this is stupid|you[\S]{0,2} (stupid|fat|dumb|ugly)",
		["Well that's not very nice. :pouting_face:", "I'm doing my best. :disappointed_face:", ":broken_heart:"]
	),
	Nicety(
		"whats your name|who are you|what do you call yourself",
		["Keeper!"]
	),
	Nicety(
		"i love you|.*you[\S]{0,2} ((pretty|so) )?(cool|neat|smart|(the (best|greatest)))|you rock",
		[u"You're pretty cool too! :sunglasses:"]
	),
	Nicety(
		"I(m| am) sorry|apologies|I apologize|sry",
		[u"That's ok.", "Don't worry about it.", "No worries.", "I'm over it."]
	),
	Nicety(
		"see you later|i have to go$",
		[u"Ok, I'm here if you need me! \U0001F603"]
	),
	Nicety(
		"thats (all|it)( for (right )?now)?|(nothing|not) ((right|for) now|at the moment)",
		None
	),
	Nicety(
		"are you( a)? real( person)?|are you human|are you an? (computer|machine)|are you an ai",
		["Do you think I am?"]
	),
	Nicety(
		"(is this|are you).* (human|ai|a machine|automated|computer|person)",
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
		[u":wave: See ya! Lmk if you need anything!"]
	),
	Nicety(
		"have a(n)? [\w]+ day",
		["Thanks, you too! :smile:"]
	),
	Nicety(
		"(can you |please )?call me\b|can i call you",
		["Sorry, I can only txt at the moment."]
	),
	Nicety(
		"are we friends|can we be friends",
		["I like to think so! :smiling_face_with_smiling_eyes:"]
	),
	Nicety(
		"will you be my friend",
		["Certainly! But I'm not very smart yet. :hatching_chick:"]
	),
	Nicety(
		"can .* motivational support",
		["Go go go! :chequered_flag:", "You can do it! :face_with_ok_gesture:", "To infinity, and beyond! :rocket:"]
	),
	Nicety(
		"do you (like|love) me",
		["I think you're pretty cool! :sunglasses:"]
	),
	Nicety(
		"do you like .+",
		["I love it! ", "Sometimes, it depends on the day.", "It's ok.", "Meh."]
	),
	Nicety(
		"whats (up|going on|new)",
		["Chillin :sunglasses:", "Workin hard. :information_desk_person:", "Nothing much. :bath:"]
	),
	Nicety(
		"this is (weird|strange|odd|different)",
		["You're telling me!"]
	),
	Nicety(
		"can i call you .+|i('m| am) going to call you .+",
		["You can call me whatever you'd like! :information_desk_person:"]
	),
	Nicety(
		"(will you )?marry me|can we be together|will you go out with me|be mine$",
		["Sorry, I'm already taken! :bride_with_veil: I'm here to help you remember stuff though!"]
	),
	Nicety(
		"good (morning|evening|afternoon|day)",
		["Thanks, same to you! :smiling_face_with_smiling_eyes:"]
	),
	Nicety(
		"how much .* cost|is .+ free",
		["My help is free! :person_raising_both_hands_in_celebration: Msg and data rates may apply."]
	),
	Nicety(
		"that was(nt| not) funny|that(s| was) a (terrible|bad|awful) joke|i did(nt| not) laugh|.*wheres my pony|thats not funny",
		["Fine. Here's your pony :horse:"]
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
	if time_utils.isDateOlderThan(user.last_feedback_prompt, keeper_constants.FEEDBACK_FREQUENCY_DAYS) and user.activated < date_util.now(pytz.utc) - datetime.timedelta(days=keeper_constants.FEEDBACK_MIN_ACTIVATED_TIME_IN_DAYS):
		user.last_feedback_prompt = date_util.now(pytz.utc)
		user.save()
		logger.info("Asked to talk to user: %s" % (user.id))

		return "%s %s" % (base, keeper_constants.FEEDBACK_PHRASE)
	elif time_utils.isDateOlderThan(user.last_share_upsell, keeper_constants.SHARE_UPSELL_FREQUENCY_DAYS) and user.completed_tutorial == True:
		user.last_share_upsell = date_util.now(pytz.utc)
		user.save()
		phrase, link = random.choice(keeper_constants.SHARE_UPSELL_PHRASES)
		if link == keeper_constants.SHARE_UPSELL_WEBLINK:
			link = user.getInviteUrl()
		else:
			link = user.getKeeperNumber()
			if len(link) > 5:  # dealing with 'test' phone numbers
				link = phonenumbers.format_number(phonenumbers.parse(user.getKeeperNumber(), 'US'), phonenumbers.PhoneNumberFormat.NATIONAL)
		return "%s %s %s!" % (base, phrase, link)
	else:
		return base


@custom_nicety_for(r'how old are (you|u)|whats your birthday|when were you born')
def renderBirthdayInquiry(user, requestDict, keeperNumber):
	delta = datetime.date.today() - keeper_constants.KEEPER_BIRTHDAY
	deltaText = humanize.naturaldelta(delta)
	return u"I was born on April 29th, 2015. That makes me about %s old! \U0001F423" % (deltaText)


EMOJI_NICETY_RE = u'(([\U00002600-\U000027BF])|([\U0001f300-\U0001f64F])|([\U0001f680-\U0001f6FF]))$'
try:
	re.compile(EMOJI_NICETY_RE)
except:
	EMOJI_NICETY_RE = (u'(([\u2600-\u27BF])|([\uD83C][\uDF00-\uDFFF])|([\uD83D][\uDC00-\uDE4F])|([\uD83D][\uDE80-\uDEFF]))$')


@custom_nicety_for(EMOJI_NICETY_RE)
def renderRandomEmoji(user, requestDict, keeperNumber):
	return random.choice(emoji.EMOJI_UNICODE.values())


@custom_nicety_for(r'what is your link|how do i share (you|keeper|this)')
def renderShareRequest(user, requestDict, keeperNumber):
	return ":clapping_hands_sign: Please send them to %s and thanks!" % (user.getInviteUrl())


@custom_nicety_for(r'what(s| is) my name|keeper$')
def renderNameQuery(user, requestDict, keeperNumber):
	return "%s!" % (user.name.title())


@custom_nicety_for(r'(my name isnt|my names not|im not) roger')
def renderRogerConfusion(user, requestDict, keeperNumber):
	return "I know, it's just an expression %s!" % (user.name.title())


# for nicety in SMSKEEPER_NICETIES:
# 	print nicety

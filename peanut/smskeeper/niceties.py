from __future__ import division

import datetime
import humanize
import emoji
import random
import re
import pytz
import logging
import phonenumbers

from django.conf import settings

from smskeeper import keeper_constants, keeper_strings
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

	def matchScore(self, msg):
		if not msg or msg == "":
			return False
		cleanedMsg = msg_util.cleanMsgText(msg)

		# We do this so we can look at a full match of a string.
		reStr = "(" + self.reStr.replace(".*", "") + ")"
		match = re.match(reStr, cleanedMsg, re.I)

		longestMatch = 0
		if match:
			for group in match.groups():
				if group and len(group) > longestMatch:
					longestMatch = len(group)

		return longestMatch / len(cleanedMsg)

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


SMSKEEPER_NICETIES = [Nicety(x[0], x[1]) for x in keeper_strings.NICETIES_LIST]


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


@custom_nicety_for(r'.*thanks( keeper)?|.*thank ?(you|u)( (very|so) much)?( keeper)?|(ok )?(ty|thx|thz|thks|thnx|thanx)( keeper)?$')
def renderThankYouResponse(user, requestDict, keeperNumber):
	base = random.choice(keeper_strings.THANKYOU_RESPONSES)
	'''
	if time_utils.isDateOlderThan(user.last_feedback_prompt, keeper_constants.FEEDBACK_FREQUENCY_DAYS) and user.activated < date_util.now(pytz.utc) - datetime.timedelta(days=keeper_constants.FEEDBACK_MIN_ACTIVATED_TIME_IN_DAYS):
		user.last_feedback_prompt = date_util.now(pytz.utc)
		user.save()
		logger.info("Asked to talk to user: %s" % (user.id))

		return "%s %s" % (base, keeper_strings.FEEDBACK_PHRASE)
	'''
	if time_utils.isDateOlderThan(user.last_share_upsell, keeper_constants.SHARE_UPSELL_FREQUENCY_DAYS) and time_utils.isDateOlderThan(user.activated, keeper_constants.SHARE_UPSELL_MIN_ACTIVATED_DAYS) and user.completed_tutorial is True:
		user.last_share_upsell = date_util.now(pytz.utc)
		user.save()
		phrase, link = random.choice(keeper_strings.SHARE_UPSELL_PHRASES)
		if link == keeper_constants.SHARE_UPSELL_WEBLINK:
			link = user.getInviteUrl()
		else:
			link = user.getKeeperNumber()
			if len(link) > 5:  # dealing with 'test' phone numbers
				if 'whatsapp' in link:  # dealing with whatsapp number
					index = link.find('@')
					if index > 0:
						link = link[:index]
						link = phonenumbers.format_number(phonenumbers.parse(link, 'US'), phonenumbers.PhoneNumberFormat.INTERNATIONAL)
						link += ' on whatsapp'
				else:
					if settings.KEEPER_NUMBER_DICT[0] in link:
						link = settings.KEEPER_NUMBER_DICT[1]  # this is to stop people from signing up for phone number associated with product_id 0
					try:
						link = phonenumbers.format_number(phonenumbers.parse(user.getKeeperNumber(), 'US'), phonenumbers.PhoneNumberFormat.NATIONAL)
					except:
						logger.error("Error trying to parse %s", user.getKeeperNumber())

		return "%s %s %s!" % (base, phrase, link)
	else:
		return base


@custom_nicety_for(r'.*how old are (you|u)|whats your birthday|when were you born')
def renderBirthdayInquiry(user, requestDict, keeperNumber):
	delta = datetime.date.today() - keeper_constants.KEEPER_BIRTHDAY
	deltaText = humanize.naturaldelta(delta)
	return keeper_strings.AGE_RESPONSE % (deltaText)


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
	return keeper_strings.HOW_DO_I_SHARE_KEEPER_RESPONSE % (user.getInviteUrl())


@custom_nicety_for(r'what(s| is) my name|keeper$')
def renderNameQuery(user, requestDict, keeperNumber):
	return "%s!" % (user.name.title())


@custom_nicety_for(r'(my name isnt|my names not|im not) roger')
def renderRogerConfusion(user, requestDict, keeperNumber):
	return keeper_strings.MY_NAME_IS_NOT_ROGER_RESPONSE % (user.name.title())


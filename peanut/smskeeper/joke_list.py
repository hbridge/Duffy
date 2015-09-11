#!/usr/bin/python
# -*- coding: utf-8 -*-
import logging

from smskeeper import sms_util
from smskeeper import keeper_constants, keeper_strings

logger = logging.getLogger(__name__)


class Joke():
	jokeType = None
	jokeData = None

	def __init__(self, jokeType, jokeData):
		self.jokeType = jokeType
		self.jokeData = jokeData

	def takesResponse(self):
		if self.jokeType == RESPONSE:
			return True
		return False

	def send(self, user, step=None, msg=None):
		if self.jokeType == ONE_LINER:
			sms_util.sendMsg(user, self.jokeData, classification=keeper_constants.OUTGOING_JOKE)
			return True
		elif self.jokeType == EQUAL_PAUSE:
			sms_util.sendMsgs(user, self.jokeData, classification=keeper_constants.OUTGOING_JOKE)
			return True
		elif self.jokeType == LONG_PAUSE:
			firstPart = self.jokeData[:-1]
			lastPart = self.jokeData[-1]

			secondsDelayed = sms_util.sendMsgs(user, firstPart)
			sms_util.sendDelayedMsg(user, lastPart, secondsDelayed + 5, classification=keeper_constants.OUTGOING_JOKE)
			return True
		elif self.jokeType == RESPONSE:
			if step == 0:
				sms_util.sendMsg(user, self.jokeData[0], classification=keeper_constants.OUTGOING_JOKE)
				return False  # Joke not done yet
			else:
				if msg and msg == self.jokeData[1].lower():
					sms_util.sendMsg(user, keeper_strings.JOKE_USER_GUESSED_IT_RIGHT)
				else:
					sms_util.sendMsg(user, self.jokeData[1], classification=keeper_constants.OUTGOING_JOKE)
				return True

	def __str__(self):
		string = "%s %s" % (self.jokeType, self.jokeData)
		return string.encode('utf-8')


def getJoke(jokeNum):
	if jokeNum < len(JOKE_LIST):
		return JOKE_LIST[jokeNum]
	return None

ONE_LINER = 0
RESPONSE = 1
LONG_PAUSE = 2
EQUAL_PAUSE = 3

JOKE_LIST = [
	Joke(RESPONSE, keeper_strings.JOKE1),
	Joke(RESPONSE, keeper_strings.JOKE2),
	Joke(RESPONSE, keeper_strings.JOKE3),
	Joke(RESPONSE, keeper_strings.JOKE4),
	Joke(RESPONSE, keeper_strings.JOKE5),
	Joke(RESPONSE, keeper_strings.JOKE6),
	Joke(RESPONSE, keeper_strings.JOKE7),
	Joke(RESPONSE, keeper_strings.JOKE8),
	Joke(RESPONSE, keeper_strings.JOKE9),
	Joke(RESPONSE, keeper_strings.JOKE10),
	Joke(RESPONSE, keeper_strings.JOKE11),
	Joke(RESPONSE, keeper_strings.JOKE12),
	Joke(RESPONSE, keeper_strings.JOKE13),
	Joke(RESPONSE, keeper_strings.JOKE14),
	Joke(RESPONSE, keeper_strings.JOKE15),
	Joke(RESPONSE, keeper_strings.JOKE16),
	Joke(RESPONSE, keeper_strings.JOKE17),
	Joke(RESPONSE, keeper_strings.JOKE18),
	Joke(RESPONSE, keeper_strings.JOKE19),
	Joke(RESPONSE, keeper_strings.JOKE20),
	Joke(RESPONSE, keeper_strings.JOKE21),
	Joke(RESPONSE, keeper_strings.JOKE22),
	Joke(RESPONSE, keeper_strings.JOKE23),
	Joke(RESPONSE, keeper_strings.JOKE24),
	Joke(RESPONSE, keeper_strings.JOKE25),
]

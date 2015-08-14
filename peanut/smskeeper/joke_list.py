#!/usr/bin/python
# -*- coding: utf-8 -*-
import logging

from smskeeper import sms_util
from smskeeper import keeper_constants

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
					sms_util.sendMsg(user, "Haha, yup!")
				else:
					sms_util.sendMsg(user, self.jokeData[1], classification=keeper_constants.OUTGOING_JOKE)
				return True

	def __str__(self):
		string = "%s %s" % (self.jokeType, self.jokeData)
		return string.encode('utf-8')


def getJoke(jokeNum):
	if jokeNum < len(JOKES):
		return JOKES[jokeNum]
	return None

ONE_LINER = 0
RESPONSE = 1
LONG_PAUSE = 2
EQUAL_PAUSE = 3

JOKES = [
	Joke(RESPONSE, ["What do you call a boomerang that doesn't come back?", "A stick"]),
	Joke(RESPONSE, ["What do you call two banana peels?", "A pair of slippers"]),
	Joke(RESPONSE, ["How do you make a tissue dance?", "Put a little boogie in it"]),
	Joke(RESPONSE, ["What do you call cheese that’s not yours?", "Nacho cheese"]),
	Joke(RESPONSE, ["Why did the belt get locked up?", "It held up a pair of pants"]),
	Joke(RESPONSE, ["Where do animals go when their tails fall off?", "The retail store"]),
	Joke(RESPONSE, ["Why can't you hear a pterodactyl going to the bathroom?", "Because the \"P\" is silent"]),
	Joke(RESPONSE, ["How does a train eat?", "It goes chew chew"]),
	Joke(RESPONSE, ["Did you hear about the constipated mathematician?", "He worked his problem out with a pencil"]),
	Joke(RESPONSE, ["What did the buffalo say to his son when he left for college?", "Bison"]),
	Joke(RESPONSE, ["What did the pirate say when he turned 80?", "Aye Matey"]),
	Joke(RESPONSE, ["Did you hear about the ATM that got addicted to money?", "It suffered from withdrawals"]),
	Joke(RESPONSE, ["Why do cows wear bells?", "Because their horns don't work"]),
	Joke(RESPONSE, ["Why couldn't the bicycle stand up?", "Because it was two tired!"]),
	Joke(RESPONSE, ["What word becomes shorter when you add two letters to it?", "Short"]),
	Joke(RESPONSE, ["What time does Sean Connery show up to Wimbledon?", "Tennish"]),
	Joke(RESPONSE, ["What happens to a frog's car when it breaks down?", "It gets toad away"]),
	Joke(RESPONSE, ["Why did the tomato blush?", "It saw the salad dressing"]),
	Joke(RESPONSE, ["What did Jay-Z call his girlfriend before they got married?", u"Feyoncé"]),
	Joke(RESPONSE, ["How many kids with ADHD does it take to change a light bulb?", "Let's go play on our bikes"]),
	Joke(RESPONSE, ["How do you communicate with a fish?", "Drop it a line"]),
	Joke(RESPONSE, ["What goes ha ha bonk?", "A man laughing his head off"]),
	Joke(RESPONSE, ["What did the egg say to the frying pan?", "You crack me up"]),
	Joke(RESPONSE, ["What is smarter than a talking bird?", "A spelling bee"]),
]

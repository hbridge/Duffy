import logging
import re
import pytz
import datetime

from smskeeper import keeper_constants
from .action import Action
from smskeeper import sms_util
from common import date_util
from smskeeper import joke_list


logger = logging.getLogger(__name__)


class JokeAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_JOKE

	jokeRequestRegex = re.compile(r"\bjoke(s)?\b", re.I)

	LAST_JOKE_SENT_KEY = "last-joke-sent"
	JOKE_STEP_KEY = "step"
	JOKE_NUM_KEY = "joke-num"

	JOKE_START = 0
	JOKE_PART1_SENT = 1
	JOKE_DONE = 2
	SUNGLASSES_SENT = 3

	def getScore(self, chunk, user):
		score = 0.0

		now = date_util.now(pytz.utc)
		jokeState = (user.state == keeper_constants.STATE_JOKE_SENT)
		regexHit = self.jokeRequestRegex.search(chunk.normalizedText()) is not None

		recent = False
		if self.getLastJokeSentTime(user) and abs((self.getLastJokeSentTime(user) - now).total_seconds()) < 120:
			recent = True

		if regexHit:
			score = .9

		if jokeState:
			score = .7

		if recent:
			score = .6

		return score

	def execute(self, chunk, user):
		now = date_util.now(pytz.utc)
		regexHit = self.jokeRequestRegex.search(chunk.normalizedText()) is not None

		jokeNum = 0
		if user.getStateData(self.JOKE_NUM_KEY):
			jokeNum = int(user.getStateData(self.JOKE_NUM_KEY))

		recent = False
		if self.getLastJokeSentTime(user) and abs((self.getLastJokeSentTime(user) - now).total_seconds()) < 60 * 60 * 6:
			recent = True

		# Figure out the step, but only use it if it was a recent joke
		# Otherwise we'd skip ahead in other jokes
		step = self.JOKE_START
		if user.getStateData(self.JOKE_STEP_KEY) and recent:
			step = int(user.getStateData(self.JOKE_STEP_KEY))

		joke = joke_list.getJoke(jokeNum)
		if not joke:
			sms_util.sendMsg(user, "Shoot, all out of jokes! I'll go work on some new ones, ask me again later")
			return True

		# See if they sent something after our joke is done
		if recent and step == self.JOKE_DONE:
			if regexHit:
				sms_util.sendMsg(user, "Let me go write another, ask me again later")
			else:
				# Probably a laugh
				if step < self.SUNGLASSES_SENT:
					sms_util.sendMsg(user, ":sunglasses:")
					user.setStateData(self.JOKE_STEP_KEY, self.SUNGLASSES_SENT)
			return True

		if not joke.takesResponse():
			joke.send(user)
			user.setStateData(self.JOKE_NUM_KEY, jokeNum + 1)
			user.setStateData(self.LAST_JOKE_SENT_KEY, date_util.unixTime(date_util.now(pytz.utc)))
			user.setStateData(self.JOKE_STEP_KEY, self.JOKE_DONE)
		else:
			jokeDone = joke.send(user, step, chunk.normalizedText())
			user.setStateData(self.LAST_JOKE_SENT_KEY, date_util.unixTime(date_util.now(pytz.utc)))

			if jokeDone:
				user.setStateData(self.JOKE_NUM_KEY, jokeNum + 1)
				user.setStateData(self.JOKE_STEP_KEY, self.JOKE_DONE)
			else:
				user.setStateData(self.JOKE_STEP_KEY, self.JOKE_PART1_SENT)

		return True

	def getLastJokeSentTime(self, user):
		if user.getStateData(self.LAST_JOKE_SENT_KEY):
			return datetime.datetime.utcfromtimestamp(user.getStateData(self.LAST_JOKE_SENT_KEY)).replace(tzinfo=pytz.utc)
		else:
			return None

	def sendJokePart1(self, chunk, user, jokeNum):
		joke, response = self.jokes[jokeNum]
		sms_util.sendMsg(user, joke)

	def sendJokePart2(self, chunk, user, jokeNum):
		joke, response = self.jokes[jokeNum]

		if response:
			if chunk.normalizedText() == joke.lower():
				sms_util.sendMsg(user, "Haha, yup!")
			else:
				sms_util.sendMsg(user, response)



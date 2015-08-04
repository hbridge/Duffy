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
	followupRegex = re.compile(r"\b(another)\b", re.I)

	LAST_JOKE_SENT_KEY = "last-joke-sent"
	JOKE_STEP_KEY = "step"
	JOKE_NUM_KEY = "joke-num"
	JOKE_COUNT_KEY = "joke-num"  # Jokes sent that day

	JOKE_START = 0
	JOKE_PART1_SENT = 1
	JOKE_DONE = 2
	SUNGLASSES_SENT = 3

	def getScore(self, chunk, user):
		score = 0.0

		jokeState = (user.state == keeper_constants.STATE_JOKE_SENT)
		regexHit = self.jokeRequestRegex.search(chunk.normalizedText()) is not None

		recent = False
		if self.secondsSinceLastJoke(user) < 120:
			recent = True

		if regexHit:
			score = .9

		if jokeState:
			score = .7

		if recent:
			score = .6

		return score

	def execute(self, chunk, user):
		requestHit = self.jokeRequestRegex.search(chunk.normalizedText()) is not None
		followupHit = self.followupRegex.search(chunk.normalizedText()) is not None

		regexHit = (requestHit or followupHit)

		jokeNum = 0
		if user.getStateData(self.JOKE_NUM_KEY):
			jokeNum = int(user.getStateData(self.JOKE_NUM_KEY))

		recent = False
		if self.secondsSinceLastJoke(user) < 60 * 60 * 6:
			recent = True

		jokeCount = 0
		if recent:
			if user.getStateData(self.JOKE_COUNT_KEY):
				jokeCount = int(user.getStateData(self.JOKE_COUNT_KEY))

		# Figure out the step, but only use it if it was a recent joke
		# Otherwise we'd skip ahead in other jokes
		step = self.JOKE_START
		if user.getStateData(self.JOKE_STEP_KEY) and recent:
			step = int(user.getStateData(self.JOKE_STEP_KEY))

		joke = joke_list.getJoke(jokeNum)
		if not joke:
			sms_util.sendMsg(user, "Shoot, all out of jokes! I'll go work on some new ones, ask me again tomorrow")
			return True

		if regexHit and jokeCount >= 2:
			sms_util.sendMsg(user, "Let me go write another, ask me again tomorrow")
			return True

		# See if they sent something after our joke is done
		# If its not a request for another joke, then do a simple reponse or ignore
		if recent and not joke.takesResponse() and not regexHit:
			# Probably a laugh
			if step < self.SUNGLASSES_SENT:
				sms_util.sendMsg(user, ":sunglasses:")
				user.setStateData(self.JOKE_STEP_KEY, self.SUNGLASSES_SENT)
			else:
				logger.debug("User %s: Ignoring msg '%s' because I already sent back sunglasses" % (user.id, chunk.originalText))
			return True

		if not joke.takesResponse():
			joke.send(user)
			self.jokeIsDone(user, jokeNum, jokeCount)
		else:
			jokeDone = joke.send(user, step, chunk.normalizedText())
			user.setStateData(self.LAST_JOKE_SENT_KEY, date_util.unixTime(date_util.now(pytz.utc)))

			if jokeDone:
				self.jokeIsDone(user, jokeNum, jokeCount)
			else:
				user.setStateData(self.JOKE_STEP_KEY, self.JOKE_PART1_SENT)

		return True

	def jokeIsDone(self, user, jokeNum, jokeCount):
		user.setStateData(self.JOKE_NUM_KEY, jokeNum + 1)
		user.setStateData(self.JOKE_STEP_KEY, self.JOKE_DONE)
		user.setStateData(self.JOKE_COUNT_KEY, jokeCount + 1)
		user.setStateData(self.LAST_JOKE_SENT_KEY, date_util.unixTime(date_util.now(pytz.utc)))

	def secondsSinceLastJoke(self, user):
		if user.getStateData(self.LAST_JOKE_SENT_KEY):
			now = date_util.now(pytz.utc)
			lastJokeTime = datetime.datetime.utcfromtimestamp(user.getStateData(self.LAST_JOKE_SENT_KEY)).replace(tzinfo=pytz.utc)
			return abs((lastJokeTime - now).total_seconds())
		else:
			return 10000000  # Big number to say its been a while

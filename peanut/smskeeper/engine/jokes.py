import logging
import re
import pytz
import datetime

from smskeeper import keeper_constants
from .action import Action
from smskeeper import sms_util
from common import date_util
from smskeeper import joke_list, chunk_features


logger = logging.getLogger(__name__)


class JokeAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_JOKE

	jokeRequestRegex = re.compile(r"\bjoke(s)?\b", re.I)
	followupRegex = re.compile(r"\b(another)\b", re.I)

	LAST_JOKE_SENT_KEY = "last-joke-sent"
	JOKE_STEP_KEY = "step"
	JOKE_NUM_KEY = "joke-num"
	JOKE_COUNT_KEY = "joke-recent-count"  # Jokes sent that day

	JOKE_START = 0
	JOKE_PART1_SENT = 1
	JOKE_DONE = 2
	SUNGLASSES_SENT = 3

	def getScore(self, chunk, user):
		score = 0.0

		features = chunk_features.ChunkFeatures(chunk, user)

		jokeLastMsg = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_JOKE, 1)
		jokeFewLastMsg = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_JOKE, 3)
		regexHit = self.jokeRequestRegex.search(chunk.normalizedText()) is not None

		hasTimingInfo = features.hasTimingInfo()

		recent = False
		if self.secondsSinceLastJoke(user) < 120:
			recent = True

		if jokeFewLastMsg:
			score = .3

		if recent:
			score = .6

		if jokeLastMsg:
			score = .7

		if regexHit:
			score = .8

		if hasTimingInfo:
			score = 0

		return score

	def execute(self, chunk, user):
		requestHit = self.jokeRequestRegex.search(chunk.normalizedText()) is not None
		followupHit = self.followupRegex.search(chunk.normalizedText()) is not None

		regexHit = (requestHit or followupHit)

		jokeNum = 0
		if user.getStateData(self.JOKE_NUM_KEY):
			jokeNum = int(user.getStateData(self.JOKE_NUM_KEY))

		recentJokeCount = self.getRecentJokeCount(user)

		# Figure out the step, but only use it if it was a recent joke
		# Otherwise we'd skip ahead in other jokes
		step = self.JOKE_START
		jokeLastMsg = user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_JOKE, 3)
		if user.getStateData(self.JOKE_STEP_KEY) and jokeLastMsg and not regexHit:
			step = int(user.getStateData(self.JOKE_STEP_KEY))

		joke = joke_list.getJoke(jokeNum)
		if not joke:
			logger.debug("User %s: Couldn't find joke for jokeNum %s" % (user.id, jokeNum))
			sms_util.sendMsg(user, "Shoot, all out of jokes! I'll go work on some new ones, ask me again tomorrow")
			return True

		if recentJokeCount >= 2:
			if regexHit:
				logger.debug("User %s: Hit recentJokeCount for the day and this message matches my regex" % (user.id))
				sms_util.sendMsg(user, "Let me go write another, ask me again tomorrow")
				return True
			else:
				logger.debug("User %s: Ignoring msg '%s' because we hit recentJokeCount limit but this wasn't a new request" % (user.id, chunk.originalText))
				return True

		# See if they sent something after our joke is done
		# If its not a request for another joke, then do a simple reponse or ignore
		# Captures things like "haha"
		if jokeLastMsg and step == self.JOKE_DONE and not regexHit:
			# Probably a laugh
			if step < self.SUNGLASSES_SENT:
				sms_util.sendMsg(user, ":sunglasses:")
				user.setStateData(self.JOKE_STEP_KEY, self.SUNGLASSES_SENT)
				return True
			else:
				logger.debug("User %s: Ignoring msg '%s' because I already sent back sunglasses" % (user.id, chunk.originalText))
				return True

		if not joke.takesResponse():
			joke.send(user)
			self.jokeIsDone(user, jokeNum, recentJokeCount)
		else:
			jokeDone = joke.send(user, step, chunk.normalizedText())
			user.setStateData(self.LAST_JOKE_SENT_KEY, date_util.unixTime(date_util.now(pytz.utc)))

			if jokeDone:
				self.jokeIsDone(user, jokeNum, recentJokeCount)
			else:
				user.setStateData(self.JOKE_STEP_KEY, self.JOKE_PART1_SENT)

		return True

	def jokeIsDone(self, user, jokeNum, recentJokeCount):
		user.setStateData(self.JOKE_NUM_KEY, jokeNum + 1)
		user.setStateData(self.JOKE_STEP_KEY, self.JOKE_DONE)

		seconds = self.secondsSinceLastJoke(user)
		if seconds > 60 * 60 * 6:
			user.setStateData(self.JOKE_COUNT_KEY, 1)
		else:
			user.setStateData(self.JOKE_COUNT_KEY, recentJokeCount + 1)
		user.setStateData(self.LAST_JOKE_SENT_KEY, date_util.unixTime(date_util.now(pytz.utc)))

	def getRecentJokeCount(self, user):
		seconds = self.secondsSinceLastJoke(user)
		if seconds > 60 * 60 * 6:
			return 0

		if user.getStateData(self.JOKE_COUNT_KEY):
			return int(user.getStateData(self.JOKE_COUNT_KEY))
		else:
			return 0

	def secondsSinceLastJoke(self, user):
		if user.getStateData(self.LAST_JOKE_SENT_KEY):
			now = date_util.now(pytz.utc)
			lastJokeTime = datetime.datetime.utcfromtimestamp(user.getStateData(self.LAST_JOKE_SENT_KEY)).replace(tzinfo=pytz.utc)
			return abs((lastJokeTime - now).total_seconds())
		else:
			return 10000000  # Big number to say its been a while

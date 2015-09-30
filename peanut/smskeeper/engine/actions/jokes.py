import logging
import pytz

from smskeeper import keeper_constants, keeper_strings
from .action import Action
from smskeeper import sms_util
from common import date_util
from smskeeper import joke_list, analytics


logger = logging.getLogger(__name__)


class JokeAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_JOKE

	JOKE_START = 0
	JOKE_PART1_SENT = 1
	JOKE_DONE = 2
	SUNGLASSES_SENT = 3

	def getScore(self, chunk, user, features):
		score = 0.0

		if features.secondsSinceLastJoke < 120:
			score = .7

		if features.wasRecentlySentMsgOfClassJoke:
			score = .7

		if features.hasJokePhrase:
			score = .8

		if features.hasTimingInfo:
			score = 0

		return score

	def execute(self, chunk, user, features):
		regexHit = (features.hasJokePhrase or features.hasJokeFollowupPhrase)

		# Which joke we're currently on
		jokeNum = 0
		if user.getStateData(keeper_constants.JOKE_NUM_KEY):
			jokeNum = int(user.getStateData(keeper_constants.JOKE_NUM_KEY))

		joke = joke_list.getJoke(jokeNum)
		if not joke:
			logger.debug("User %s: Couldn't find joke for jokeNum %s" % (user.id, jokeNum))
			sms_util.sendMsg(user, keeper_strings.JOKES_NO_MORE_TEXT)
			return True

		# How many jokes we've told in the last 6 hours
		recentJokeCount = self.getRecentJokeCount(user, features.secondsSinceLastJoke)

		recent = False
		if features.secondsSinceLastJoke < 120:
			recent = True

		# If we've told too many, then see if they're asking for another
		# If so, give them a response, if not, kick out for re-processing
		if recentJokeCount >= 4:
			if regexHit:
				logger.debug("User %s: Hit recentJokeCount for the day and this message matches my regex" % (user.id))
				sms_util.sendMsg(user, keeper_strings.JOKES_MAX_SENT_TODAY_TEXT)
				return True
			else:
				logger.debug("User %s: Kicking out from jokes with msg '%s' because we hit recentJokeCount limit but this wasn't a new request" % (user.id, chunk.originalText))
				return False

		if user.getStateData(keeper_constants.JOKE_STEP_KEY):
			step = int(user.getStateData(keeper_constants.JOKE_STEP_KEY))
		else:
			step = self.JOKE_START

		if step == self.JOKE_START:
			self.sendJokePart1(user, joke, recentJokeCount, features.secondsSinceLastJoke)

			analytics.logUserEvent(
				user,
				"Joke request",
				{
				}
			)
		elif step == self.JOKE_PART1_SENT:
			# eval guess
			joke.send(user, step, chunk.normalizedText())
			self.jokeIsDone(user, jokeNum, recentJokeCount, features.secondsSinceLastJoke)
		elif step == self.JOKE_DONE:
			# if regex hit, then send another
			if regexHit:
				self.sendJokePart1(user, joke, recentJokeCount, features.secondsSinceLastJoke)
			elif recent:
				sms_util.sendMsg(user, keeper_strings.JOKE_LAST_STEP)
				user.setStateData(keeper_constants.JOKE_STEP_KEY, self.SUNGLASSES_SENT)
			else:
				logger.debug("User %s: Kicking out from jokes with msg '%s' because joke was done" % (user.id, chunk.originalText))
				return False
		elif step == self.SUNGLASSES_SENT:
			if regexHit:
				self.sendJokePart1(user, joke, recentJokeCount, features.secondsSinceLastJoke)
			elif chunk.contains("pony"):
				sms_util.sendMsg(user, keeper_strings.PONY_RESPONSE)
			else:
				logger.debug("User %s: Kicking out from jokes with msg '%s' because joke was done with sunglasses" % (user.id, chunk.originalText))
				return False

		return True

	def sendJokePart1(self, user, joke, recentJokeCount, secondsSinceLastJoke):
		joke.send(user, self.JOKE_START)
		user.setStateData(keeper_constants.JOKE_STEP_KEY, self.JOKE_PART1_SENT)
		user.setStateData(keeper_constants.LAST_JOKE_SENT_KEY, date_util.unixTime(date_util.now(pytz.utc)))
		user.setStateData(keeper_constants.JOKE_COUNT_KEY, recentJokeCount)

	def jokeIsDone(self, user, jokeNum, recentJokeCount, secondsSinceLastJoke):
		user.setStateData(keeper_constants.JOKE_NUM_KEY, jokeNum + 1)
		user.setStateData(keeper_constants.JOKE_STEP_KEY, self.JOKE_DONE)

		if secondsSinceLastJoke > 60 * 60 * 6:
			user.setStateData(keeper_constants.JOKE_COUNT_KEY, 1)
		else:
			user.setStateData(keeper_constants.JOKE_COUNT_KEY, recentJokeCount + 1)
		user.setStateData(keeper_constants.LAST_JOKE_SENT_KEY, date_util.unixTime(date_util.now(pytz.utc)))

	def getRecentJokeCount(self, user, secondsSinceLastJoke):
		if secondsSinceLastJoke > 60 * 60 * 6:
			return 0

		if user.getStateData(keeper_constants.JOKE_COUNT_KEY):
			return int(user.getStateData(keeper_constants.JOKE_COUNT_KEY))
		else:
			return 0

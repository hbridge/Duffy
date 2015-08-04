import logging
import re

from smskeeper import keeper_constants
from .action import Action
from smskeeper import sms_util


logger = logging.getLogger(__name__)


class JokeAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_JOKE

	jokeRequestRegex = re.compile(r"\bjoke(s)?\b", re.I)

	def getScore(self, chunk, user):
		score = 0.0

		justSentJoke = (user.state == keeper_constants.STATE_JOKE_SENT)
		regexHit = self.jokeRequestRegex.search(chunk.normalizedText()) is not None
		if regexHit:
			score = .9

		if justSentJoke:
			score = .7

		return score

	def execute(self, chunk, user):
		regexHit = self.jokeRequestRegex.search(chunk.normalizedText()) is not None
		jokeNum = 0

		if regexHit:
			self.sendJokePart1(chunk, user, jokeNum)
			user.setState(keeper_constants.STATE_JOKE_SENT)
		else:
			self.sendJokePart2(chunk, user, jokeNum)
			user.setState(keeper_constants.STATE_NORMAL)

		return True

	def sendJokePart1(self, chunk, user, jokeNum):
		joke, response = self.jokes[jokeNum]
		sms_util.sendMsg(user, joke)

	def sendJokePart2(self, chunk, user, jokeNum):
		joke, response = self.jokes[jokeNum]
		if chunk.normalizedText() == joke.lower():
			sms_util.sendMsg(user, "Haha, yup!")
		else:
			sms_util.sendMsg(user, response)

	jokes = [
		("What do you call a boomerang that doesn't come back?", "A stick"),
	]

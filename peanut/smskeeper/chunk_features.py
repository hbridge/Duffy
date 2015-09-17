import datetime
import logging
import pytz

from smskeeper import entry_util
import phonenumbers
from smskeeper import keeper_constants
from smskeeper import msg_util, niceties
import collections

from common import date_util

logger = logging.getLogger(__name__)


def makeRegisteringDecorator(foreignDecorator):
	"""
		Returns a copy of foreignDecorator, which is identical in every
		way(*), except also appends a .decorator property to the callable it
		spits out.
	"""
	def newDecorator(func):
		# Call to newDecorator(method)
		# Exactly like old decorator, but output keeps track of what decorated it
		R = foreignDecorator(func)  # apply foreignDecorator, like call to foreignDecorator(method) would have done
		R.decorator = newDecorator  # keep track of decorator
		return R

	newDecorator.__name__ = foreignDecorator.__name__
	newDecorator.__doc__ = foreignDecorator.__doc__
	# (*)We can be somewhat "hygienic", but newDecorator still isn't signature-preserving, i.e. you will not be able to get a runtime list of parameters. For that, you need hackish libraries...but in this case, the only argument is func, so it's not a big issue

	return newDecorator


def feature(fn):
	def new(*args):
		return fn(*args)

	new.__name__ = fn.__name__
	return new

feature = makeRegisteringDecorator(feature)


class ChunkFeatures:
	chunk = None
	user = None

	def __init__(self, chunk, user):
		self.chunk = chunk
		self.user = user

	# things that match this RE will get a boost for done
	beginsWithDoneWordRegex = r'^(done|check off|mark off) '

	help_re = r'help$|how do .* work|what .*(can|do) you do|tell me more'

	# NOTE: Make sure there's a space after these words, otherwise "printed" will match
	# things that match this RE will get a boost for create
	createWordRegex = "(remind|to do|buy|watch|print|fax|go|get|study|wake|fix|make|schedule|fill|find|clean|pick up|cut|renew|fold|mop|pack|pay|call|send|wash|email|edit|talk|do|prepare|order|shop)"
	beginsWithCreateWordRegex = r'^%s ' % createWordRegex
	containsCreateWordhRegex = r'\b%s ' % createWordRegex

	weatherRegex = r"\b(weather|forecast|rain|temp|temperature|how hot)\b"

	# Changetime most recent
	changeTimeBasicRegex = r"\b(snooze|again|change)\b"
	changeTimeBeginsWithRegex = r'^(change|snooze|update|again|remind (me )?again) '

	# Jokes
	jokeRequestRegex = r"\bjoke(s)?\b"
	jokeFollowupRegex = r"\b(another)\b"

	# Stop
	stopRegex = r"stop$|silent stop$|cancel( keeper)?$"

	# PRIVATE
	def getInterestingWords(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		interestingWords = msg_util.getInterestingWords(cleanedText)
		return interestingWords

	def getLastActionTime(self):
		if self.user.getStateData(keeper_constants.LAST_ACTION_KEY):
			return datetime.datetime.utcfromtimestamp(self.user.getStateData(keeper_constants.LAST_ACTION_KEY)).replace(tzinfo=pytz.utc)
		else:
			return None

	# Features
	@feature
	def hasTimingInfo(self):
		if self.chunk.getNattyResult(self.user):
			return True
		return False

	@feature
	def hasTimeOfDay(self):
		nattyResult = self.chunk.getNattyResult(self.user)
		if nattyResult and nattyResult.hadTime:
			return True
		return False

	@feature
	def numInterestingWords(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		return len(msg_util.getInterestingWords(cleanedText))

	@feature
	def hasDoneWord(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	@feature
	def beginsWithDoneWord(self):
		return self.chunk.matches(self.beginsWithDoneWordRegex)

	@feature
	def beginsWithNo(self):
		return msg_util.startsWithNo(self.chunk.normalizedText())

	@feature
	def hasChangeTimeWord(self):
		return self.chunk.contains(self.changeTimeBasicRegex)

	@feature
	def beginsWithChangeTimeWord(self):
		return self.chunk.matches(self.changeTimeBeginsWithRegex)

	@feature
	def numMatchingEntriesStrict(self):
		return len(entry_util.fuzzyMatchEntries(self.user, ' '.join(self.getInterestingWords()), 80))

	@feature
	def numMatchingEntriesBroad(self):
		return len(entry_util.fuzzyMatchEntries(self.user, ' '.join(self.getInterestingWords()), 65))

	@feature
	def hasCreateWord(self):
		return self.chunk.contains(self.containsCreateWordhRegex)

	@feature
	def hasReminderPhrase(self):
		return msg_util.reminder_re.search(self.chunk.normalizedText()) is not None

	@feature
	def beginsWithCreateWord(self):
		return self.chunk.matches(self.beginsWithCreateWordRegex)

	@feature
	def beginsWithAndWord(self):
		return self.chunk.matches(r'and|also')

	@feature
	def hasPhoneNumber(self):
		matches = phonenumbers.PhoneNumberMatcher(self.chunk.originalText, 'US')
		return matches.has_next()

	@feature
	def isPhoneNumber(self):
		matches = phonenumbers.PhoneNumberMatcher(self.chunk.originalText, 'US')
		if not matches.has_next():
			return False
		match = matches.next()
		return match.start == 0 and match.end == len(self.chunk.originalText)

		return matches.has_next()

	# is the primary verb of the chunk "remind" as in "remind me to poop"
	# as opposed to "call fred tonight"
	@feature
	def primaryActionIsRemind(self):
		return self.chunk.matches(keeper_constants.SHARED_REMINDER_VERB_WHITELIST_REGEX)

	@feature
	def hasWeatherWord(self):
		return self.chunk.contains(self.weatherRegex)

	@feature
	def numWords(self):
		return len(self.chunk.normalizedText().split(' '))

	@feature
	def isQuestion(self):
		isQuestion = False
		if self.chunk.endsWith("\?", punctuationWhitelist="?"):
			isQuestion = True

		if self.chunk.matches(r'(what(s)?|where|when|how|why|who(s)?|whose|which|should|would|is|are)\b'):
			isQuestion = True

		return isQuestion

	@feature
	def isBroadQuestion(self):
		return self.chunk.matches(r'(where|how|why|who|should|would|are)\b')

	@feature
	def numFetchDigestWords(self):
		fetchDigestWords = ["tasks", "todo", "reminders", "list", "left", "reminding", "schedule", "all"]
		normalizedText = self.chunk.normalizedText()
		count = 0
		for word in fetchDigestWords:
			if word in normalizedText.split():
				count += 1

		if self.chunk.contains(r'\bto do\b'):
			count += 1

		return count

	@feature
	def isFetchDigestPhrase(self):
		return self.chunk.matches(r'tasks|todo|whats left|what am i doing')

	@feature
	def couldBeDone(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	@feature
	def containsToday(self):
		return self.chunk.contains('today')

	@feature
	def containsDeleteWord(self):
		return self.chunk.contains(r'delete|clear|remove')

	def recurScores(self):
		results = {}
		for frequency in keeper_constants.RECUR_REGEXES.keys():
			if self.chunk.contains(keeper_constants.RECUR_REGEXES[frequency]):
				if frequency == keeper_constants.RECUR_WEEKDAYS:
					# we want weekday to win out over weekly, and weekly's RE is more general
					results[frequency] = 0.9
				else:
					results[frequency] = 0.8
			else:
				results[frequency] = 0.0

		return collections.OrderedDict(
			sorted(results.items(), key=lambda t: t[1], reverse=True)
		)

	@feature
	def containsTipWord(self):
		return self.chunk.contains(r'tip')

	@feature
	def containsNegativeWord(self):
		return self.chunk.contains(r'(no|dont|not|never|stop)')

	@feature
	def containsPostalCode(self):
		return msg_util.getPostalCode(self.chunk.normalizedText()) is not None

	@feature
	def containsZipCodeWord(self):
		return self.chunk.contains(r'(zip|zip code|zipcode|moved)')

	@feature
	def containsFirstPersonWord(self):
		return self.chunk.contains(r'(\bI\b|\bmy\b)')

	@feature
	def looksLikeList(self):
		return self.chunk.contains(r'[:]', punctuationWhitelist=':')

	@feature
	def wasRecentlySentMsgOfClassReminder(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_REMINDER)

	@feature
	def wasRecentlySentMsgOfClassDigest(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_DIGEST)

	@feature
	def wasRecentlySentMsgOfClassJoke(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_JOKE)

	@feature
	def numCharactersInCleanedText(self):
		cleanedText = msg_util.cleanedReminder(msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user)))
		return len(cleanedText)

	# This could be a problem since it looks at now
	@feature
	def isRecentAction(self):
		now = date_util.now(pytz.utc)

		lastActionTime = self.getLastActionTime()
		isRecentAction = True if (lastActionTime and (now - lastActionTime) < datetime.timedelta(minutes=5)) else False

		return isRecentAction

	@feature
	def hasAnyNicety(self):
		return True if niceties.getNicety(self.chunk.originalText) else False

	@feature
	def hasSilentNicety(self):
		nicety = niceties.getNicety(self.chunk.originalText)
		if nicety and nicety.isSilent():
			return True
		return False

	@feature
	def nicetyMatchScore(self):
		nicety = niceties.getNicety(self.chunk.originalText)
		if nicety:
			return nicety.matchScore(self.chunk.originalText)
		return 0

	@feature
	def inTutorial(self):
		return not self.user.isTutorialComplete()

	@feature
	def startsWithHelpPhrase(self):
		return self.chunk.matches(self.help_re)

	@feature
	def hasJokePhrase(self):
		return self.chunk.contains(self.jokeRequestRegex)

	@feature
	def hasJokeFollowupPhrase(self):
		return self.chunk.contains(self.jokeFollowupRegex)

	@feature
	def secondsSinceLastJoke(self):
		if self.user.getStateData(keeper_constants.LAST_JOKE_SENT_KEY):
			now = date_util.now(pytz.utc)
			lastJokeTime = datetime.datetime.utcfromtimestamp(self.user.getStateData(keeper_constants.LAST_JOKE_SENT_KEY)).replace(tzinfo=pytz.utc)
			return abs((lastJokeTime - now).total_seconds())
		else:
			return 10000000  # Big number to say its been a while

	@feature
	def hasStopPhrase(self):
		return self.chunk.matches(self.stopRegex)

	# Returns True if this message has a valid time and it doesn't look like another remind command
	# If reminderSent is true, then we look for again or snooze which if found, we'll assume is a followup
	# Like "remind me again in 5 minutes"
	# If the message (without timing info) only is "remind me" then also is a followup due to "remind me in 5 minutes"
	# Otherwise False
	@feature
	def isFollowup(self):
		if not self.hasTimingInfo():
			return False

		# Covers cases where there the cleanedText is "in" or "around"
		if self.numCharactersInCleanedText() <= 2:
			logger.info("User %s: I think this is a followup to bc its less than 2 letters" % (self.user.id))
			return True
		# If they write "no, remind me sunday instead" then want to process as followup
		elif self.beginsWithNo():
			logger.info("User %s: I think this is a followup bc it starts with a No" % (self.user.id))
			return True
		elif self.numInterestingWords() == 0:
			logger.info("User %s: I think this is a followup bc there's no interesting words" % (self.user.id))
			return True
		elif self.isRecentAction() and self.numInterestingWords() < 2:
			logger.info("User %s: I think this is a followup bc we updated it recently and <2 interesting words" % (self.user.id))
			return True

		return False


def methodsWithDecorator(cls, decorator):
	"""
		Returns all methods in CLS with DECORATOR as the
		outermost decorator.

		DECORATOR must be a "registering decorator"; one
		can make any decorator "registering" via the
		makeRegisteringDecorator function.
	"""
	for maybeDecorated in cls.__dict__.values():
		if hasattr(maybeDecorated, 'decorator'):
			if maybeDecorated.decorator == decorator:
				yield maybeDecorated


def getFeatureFunctions():
	return methodsWithDecorator(ChunkFeatures, feature)


def getFeatureNames():
	result = list()
	fs = getFeatureFunctions()

	for f in fs:
		result.append(fs.__name__)
	return result


def getFeaturesDict(chunkFeatures):
	fs = getFeatureFunctions()

	result = dict()
	for f in fs:
		ret = f(chunkFeatures)

		if ret is True:
			ret = 1
		elif ret is False:
			ret = 0

		result[f.__name__] = ret

	return result


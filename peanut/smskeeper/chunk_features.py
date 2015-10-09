import datetime
import logging
import pytz
import json
from memorised.decorators import memorise

from smskeeper import entry_util
import phonenumbers
from smskeeper import keeper_constants
from smskeeper import msg_util, niceties, tips
import collections

from common import date_util

logger = logging.getLogger(__name__)


class memoized_property(object):
    def __init__(self, fget=None, fset=None, fdel=None, doc=None):
        if doc is None and fget is not None and hasattr(fget, "__doc__"):
            doc = fget.__doc__
        self.__get = fget
        self.__set = fset
        self.__del = fdel
        self.__doc__ = doc
        if fget is not None:
            self._attr_name = '___' + fget.func_name

    def __get__(self, inst, type=None):
        if inst is None:
            return self
        if self.__get is None:
            raise AttributeError, "unreadable attribute"

        if not hasattr(inst, self._attr_name):
            result = self.__get(inst)
            setattr(inst, self._attr_name, result)
        return getattr(inst, self._attr_name)

    def __set__(self, inst, value):
        if self.__set is None:
            raise AttributeError, "can't set attribute"
        delattr(inst, self._attr_name)
        return self.__set(inst, value)

    def __delete__(self, inst):
        if self.__del is None:
            raise AttributeError, "can't delete attribute"
        delattr(inst, self._attr_name)
        return self.__del(inst)


def memoized_property_set(inst, func_name, value):
    if isinstance(func_name, basestring):
        property_name = '___' + func_name
    elif hasattr(func_name, 'func_name'):
        property_name = '___' + func_name.func_name
    else:
        raise
    setattr(inst, property_name, value)


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
	createWordRegex = "(remind|to do|buy|watch|print|fax|go|get|study|wake|fix|make|schedule|fill|find|clean|pick up|cut|renew|fold|mop|pack|pay|call|send|wash|email|edit|talk|do|prepare|order|shop|read|invite|follow up|eat|check on|bring|set up|straighten up|work on|need to|sweep)"
	beginsWithCreateWordRegex = r'^%s ' % createWordRegex
	containsCreateWordhRegex = r'\b%s ' % createWordRegex

	weatherRegex = r"\b(weather|forecast|rain|temp|temperature|how hot)\b"

	# Changetime most recent
	snoozeRegex = r"\b(snooze)\b"
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

	def isInt(self, word):
		try:
			int(word)
			return True
		except ValueError:
			return False

	def getFirstInt(self, chunk):
		words = chunk.normalizedText().split(' ')
		for word in words:
			if self.isInt(word):
				firstInt = int(word)
				return firstInt
		return None

	def getMatchingEntriesStrict(self):
		return entry_util.fuzzyMatchEntries(self.user, ' '.join(self.getInterestingWords()), 80)

	def getMatchingEntriesBroad(self):
		return entry_util.fuzzyMatchEntries(self.user, ' '.join(self.getInterestingWords()), 65)

	def getJustNotifiedEntryIds(self):
		return self.user.getLastEntriesIds()

	# Features
	@memoized_property
	def hasTimingInfo(self):
		if self.chunk.getNattyResult(self.user):
			return True
		return False

	@memoized_property
	def hasTimeOfDay(self):
		nattyResult = self.chunk.getNattyResult(self.user)
		if nattyResult and nattyResult.hadTime:
			return True
		return False

	@memoized_property
	def hasDate(self):
		nattyResult = self.chunk.getNattyResult(self.user)
		if nattyResult and nattyResult.hadDate:
			return True
		return False

	@memoized_property
	def numInterestingWords(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		return len(msg_util.getInterestingWords(cleanedText))

	@memoized_property
	def hasDoneWord(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	@memoized_property
	def beginsWithDoneWord(self):
		return self.chunk.matches(self.beginsWithDoneWordRegex)

	@memoized_property
	def beginsWithNo(self):
		return msg_util.startsWithNo(self.chunk.normalizedText())

	@memoized_property
	def hasChangeTimeWord(self):
		return self.chunk.contains(self.changeTimeBasicRegex)

	@memoized_property
	def beginsWithChangeTimeWord(self):
		return self.chunk.matches(self.changeTimeBeginsWithRegex)

	@memoized_property
	def beginsWithSnooze(self):
		return self.chunk.matches(self.snoozeRegex)

	@memoized_property
	def numMatchingEntriesStrict(self):
		return len(self.getMatchingEntriesStrict())

	@memoized_property
	def numBroadEntriesJustNotifiedAbout(self):
		bestEntries = self.getMatchingEntriesBroad()
		bestEntryIds = [x.id for x in bestEntries]
		justNotifiedEntryIds = self.user.getLastEntriesIds()

		return len(set(bestEntryIds).intersection(set(justNotifiedEntryIds)))

	@memoized_property
	def numLastNotifiedEntries(self):
		return len(self.getJustNotifiedEntryIds())

	@memoized_property
	def numMatchingEntriesBroad(self):
		return len(self.getMatchingEntriesBroad())

	@memoized_property
	def scoreOfTopEntry(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		cleanedText = ' '.join(msg_util.getInterestingWords(cleanedText))
		entry, score = entry_util.getBestEntryMatch(self.user, cleanedText)
		if entry:
			return score
		else:
			return 0

	@memoized_property
	def numActiveEntries(self):
		return len(self.user.getActiveEntries())

	@memoized_property
	def hasCreateWord(self):
		return self.chunk.contains(self.containsCreateWordhRegex)

	@memoized_property
	def hasReminderPhrase(self):
		return msg_util.reminder_re.search(self.chunk.normalizedText()) is not None

	@memoized_property
	def beginsWithCreateWord(self):
		return self.chunk.matches(self.beginsWithCreateWordRegex)

	@memoized_property
	def beginsWithAndWord(self):
		return self.chunk.matches(r'and|also')

	@memoized_property
	@memorise(parent_keys=['chunk'])
	def hasPhoneNumber(self):
		matches = phonenumbers.PhoneNumberMatcher(self.chunk.originalText, 'US')
		return matches.has_next()

	@memoized_property
	@memorise(parent_keys=['chunk'])
	def isPhoneNumber(self):
		matches = phonenumbers.PhoneNumberMatcher(self.chunk.originalText, 'US')
		if not matches.has_next():
			return False
		match = matches.next()
		return match.start == 0 and match.end == len(self.chunk.originalText)

		return matches.has_next()

	# is the primary verb of the chunk "remind" as in "remind me to poop"
	# as opposed to "call fred tonight"
	@memoized_property
	def primaryActionIsRemind(self):
		return self.chunk.matches(keeper_constants.SHARED_REMINDER_VERB_WHITELIST_REGEX)

	@memoized_property
	def hasWeatherWord(self):
		return self.chunk.contains(self.weatherRegex)

	@memoized_property
	def numWords(self):
		return len(self.chunk.normalizedText().split(' '))

	@memoized_property
	def isQuestion(self):
		isQuestion = False
		if self.chunk.endsWith("\?", punctuationWhitelist="?"):
			isQuestion = True

		if self.chunk.matches(r'(what(s)?|where|when|how|why|who(s)?|whose|which|should|would|is|are)\b'):
			isQuestion = True

		return isQuestion

	@memoized_property
	def isBroadQuestion(self):
		return self.chunk.matches(r'(where|how|why|who|should|would|are)\b')

	@memoized_property
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

	@memoized_property
	def isFetchDigestPhrase(self):
		return self.chunk.matches(r'tasks|todo|whats left|what am i doing')

	@memoized_property
	def couldBeDone(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	@memoized_property
	def containsToday(self):
		return self.chunk.contains('today')

	@memoized_property
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

	@memoized_property
	def containsTipWord(self):
		return self.chunk.contains(r'tip')

	@memoized_property
	def containsNegativeWord(self):
		return self.chunk.contains(r'(no|dont|not|never|stop)')

	@memoized_property
	def containsPostalCode(self):
		return msg_util.getPostalCode(self.chunk.normalizedText()) is not None

	@memoized_property
	def containsZipCodeWord(self):
		return self.chunk.contains(r'(zip|zip code|zipcode|moved)')

	@memoized_property
	def containsFirstPersonWord(self):
		return self.chunk.contains(r'(\bI\b|\bmy\b)')

	@memoized_property
	def looksLikeList(self):
		return self.chunk.contains(r'[:]', punctuationWhitelist=':')

	@memoized_property
	def wasRecentlySentMsgOfClassReminder(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_REMINDER)

	@memoized_property
	def wasRecentlySentMsgOfClassDigest(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_DIGEST)

	@memoized_property
	def wasRecentlySentMsgOfClassJoke(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_JOKE)

	@memoized_property
	def wasRecentlySentMsgOfClassChangeDigestTime(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_CHANGE_DIGEST_TIME, 2)

	@memoized_property
	def wasRecentlySentMsgOfClassReferralAsk(self):
		return self.user.wasRecentlySentMsgOfClass(tips.REFERRAL_ASK_TIP_ID, 2)

	@memoized_property
	def wasRecentlySentMsgOfClassNpsTip(self):
		return self.user.wasRecentlySentMsgOfClass(tips.DIGEST_QUESTION_NPS_TIP_ID, 2)

	@memoized_property
	def wasRecentlySentMsgOfClassDigestSurvey(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SURVEY, 2)

	@memoized_property
	def userMissingNpsInfo(self):
		return self.user.getStateData(keeper_constants.NPS_DATA_KEY) is None

	@memoized_property
	def userMissingReferralInfo(self):
		if self.user.signup_data_json:
			signupData = json.loads(self.user.signup_data_json)
		else:
			signupData = "{}"

		return ("referrer" not in signupData or len(signupData["referrer"]) == 0)

	@memoized_property
	def userMissingDigestSurveyInfo(self):
		return self.user.getStateData(keeper_constants.DIGEST_SURVEY_DATA_KEY) is None

	@memoized_property
	def hasIntFirst(self):
		words = self.chunk.normalizedText().split(' ')

		if len(words) > 0:
			return self.isInt(words[0])
		return False

	@memoized_property
	def hasInt(self):
		words = self.chunk.normalizedText().split(' ')

		hasInt = False

		for word in words:
			if self.isInt(word):
				hasInt = True
		return hasInt

	@memoized_property
	def numCharactersInCleanedText(self):
		cleanedText = msg_util.cleanedReminder(msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user)))
		return len(cleanedText)

	# This could be a problem since it looks at now
	@memoized_property
	def isRecentAction(self):
		now = date_util.now(pytz.utc)

		lastActionTime = self.getLastActionTime()
		isRecentAction = True if (lastActionTime and (now - lastActionTime) < datetime.timedelta(minutes=5)) else False

		return isRecentAction

	@memoized_property
	@memorise(parent_keys=['chunk'])
	def hasAnyNicety(self):
		return True if niceties.getNicety(self.chunk.normalizedText()) else False

	@memoized_property
	@memorise(parent_keys=['chunk'])
	def hasSilentNicety(self):
		nicety = niceties.getNicety(self.chunk.normalizedText())
		if nicety and nicety.isSilent():
			return True
		return False

	@memoized_property
	@memorise(parent_keys=['chunk'])
	def nicetyMatchScore(self):
		nicety = niceties.getNicety(self.chunk.normalizedText())
		if nicety:
			return nicety.matchScore(self.chunk.normalizedText())
		return 0

	@memoized_property
	def inTutorial(self):
		return not self.user.isTutorialComplete()

	@memoized_property
	def startsWithHelpPhrase(self):
		return self.chunk.matches(self.help_re)

	@memoized_property
	def hasJokePhrase(self):
		return self.chunk.contains(self.jokeRequestRegex)

	@memoized_property
	def hasJokeFollowupPhrase(self):
		return self.chunk.contains(self.jokeFollowupRegex)

	@memoized_property
	def secondsSinceLastJoke(self):
		if self.user.getStateData(keeper_constants.LAST_JOKE_SENT_KEY):
			now = date_util.now(pytz.utc)
			lastJokeTime = datetime.datetime.utcfromtimestamp(self.user.getStateData(keeper_constants.LAST_JOKE_SENT_KEY)).replace(tzinfo=pytz.utc)
			return abs((lastJokeTime - now).total_seconds())
		else:
			return 10000000  # Big number to say its been a while

	@memoized_property
	def hasStopPhrase(self):
		return self.chunk.matches(self.stopRegex)

	# Returns True if this message has a valid time and it doesn't look like another remind command
	# If reminderSent is true, then we look for again or snooze which if found, we'll assume is a followup
	# Like "remind me again in 5 minutes"
	# If the message (without timing info) only is "remind me" then also is a followup due to "remind me in 5 minutes"
	# Otherwise False
	@memoized_property
	def isFollowup(self):
		if not self.hasTimingInfo:
			return False

		# Covers cases where there the cleanedText is "in" or "around"
		if self.numCharactersInCleanedText <= 2:
			logger.info("User %s: I think this is a followup to bc its less than 2 letters" % (self.user.id))
			return True
		# If they write "no, remind me sunday instead" then want to process as followup
		elif self.beginsWithNo:
			logger.info("User %s: I think this is a followup bc it starts with a No" % (self.user.id))
			return True
		elif self.numInterestingWords == 0:
			logger.info("User %s: I think this is a followup bc there's no interesting words" % (self.user.id))
			return True
		elif self.isRecentAction and self.numInterestingWords < 2:
			logger.info("User %s: I think this is a followup bc we updated it recently and <2 interesting words" % (self.user.id))
			return True

		return False


def getFeatureNames():
	return [p for p in dir(ChunkFeatures) if isinstance(getattr(ChunkFeatures, p), memoized_property)]


def getFeaturesDict(chunkFeatures):
	fs = getFeatureNames()

	result = dict()
	for f in fs:
		ret = getattr(chunkFeatures, f)

		if ret is True:
			ret = 1
		elif ret is False:
			ret = 0

		result[f] = ret

	return result

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

	# PRIVATE
	def getInterestingWords(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		interestingWords = msg_util.getInterestingWords(cleanedText)
		return interestingWords

	# Features
	def hasTimingInfo(self):
		if self.chunk.getNattyResult(self.user):
			return True
		return False

	def hasTimeOfDay(self):
		nattyResult = self.chunk.getNattyResult(self.user)
		if nattyResult and nattyResult.hadTime:
			return True
		return False

	def numInterestingWords(self):
		cleanedText = msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user))
		return len(msg_util.getInterestingWords(cleanedText))

	def hasDoneWord(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	def beginsWithDoneWord(self):
		return self.chunk.matches(self.beginsWithDoneWordRegex)

	def beginsWithNo(self):
		return msg_util.startsWithNo(self.chunk.normalizedText())

	def hasChangeTimeWord(self):
		return self.chunk.contains(self.changeTimeBasicRegex)

	def beginsWithChangeTimeWord(self):
		return self.chunk.matches(self.changeTimeBeginsWithRegex)

	def numMatchingEntriesStrict(self):
		return len(entry_util.fuzzyMatchEntries(self.user, ' '.join(self.getInterestingWords()), 80))

	def numMatchingEntriesBroad(self):
		return len(entry_util.fuzzyMatchEntries(self.user, ' '.join(self.getInterestingWords()), 65))

	def hasCreateWord(self):
		return self.chunk.contains(self.containsCreateWordhRegex)

	def hasReminderPhrase(self):
		return msg_util.reminder_re.search(self.chunk.normalizedText()) is not None

	def beginsWithCreateWord(self):
		return self.chunk.matches(self.beginsWithCreateWordRegex)

	def beginsWithAndWord(self):
		return self.chunk.matches(r'and|also')

	def hasPhoneNumber(self):
		matches = phonenumbers.PhoneNumberMatcher(self.chunk.originalText, 'US')
		return matches.has_next()

	def isPhoneNumber(self):
		matches = phonenumbers.PhoneNumberMatcher(self.chunk.originalText, 'US')
		if not matches.has_next():
			return False
		match = matches.next()
		return match.start == 0 and match.end == len(self.originalText)

		return matches.has_next()

	# is the primary verb of the chunk "remind" as in "remind me to poop"
	# as opposed to "call fred tonight"
	def primaryActionIsRemind(self):
		return self.chunk.matches(keeper_constants.SHARED_REMINDER_VERB_WHITELIST_REGEX)

	def hasWeatherWord(self):
		return self.chunk.contains(self.weatherRegex)

	def isQuestion(self):
		isQuestion = False
		if self.chunk.endsWith("\?", punctuationWhitelist="?"):
			isQuestion = True

		if self.chunk.matches(r'(what(s)?|where|when|how|why|who(s)?|whose|which|should|would|is|are)\b'):
			isQuestion = True

		return isQuestion

	def isBroadQuestion(self):
		return self.chunk.matches(r'(where|how|why|who|should|would|are)\b')

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

	def isFetchDigestPhrase(self):
		return self.chunk.matches(r'tasks|todo|whats left|what am i doing')

	def couldBeDone(self):
		return msg_util.done_re.search(self.chunk.normalizedText()) is not None

	def containsToday(self):
		return self.chunk.contains('today')

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

	def containsTipWord(self):
		return self.chunk.contains(r'tip')

	def containsNegativeWord(self):
		return self.chunk.contains(r'(no|dont|not|never|stop)')

	def containsPostalCode(self):
		return msg_util.getPostalCode(self.chunk.normalizedText())

	def containsZipCodeWord(self):
		return self.chunk.contains(r'(^|\b)zip( )?(code)?')

	def containsFirstPersonWord(self):
		return self.chunk.contains(r'(\bI\b|\bmy\b)')

	def looksLikeList(self):
		return self.chunk.contains(r'[:]', punctuationWhitelist=':')

	def wasRecentlySentMsgOfClassReminder(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_REMINDER)

	def wasRecentlySentMsgOfClassDigest(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_DIGEST)

	def wasRecentlySentMsgOfClassJoke(self):
		return self.user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_JOKE)

	def getLastActionTime(self, user):
		if user.getStateData(keeper_constants.LAST_ACTION_KEY):
			return datetime.datetime.utcfromtimestamp(user.getStateData(keeper_constants.LAST_ACTION_KEY)).replace(tzinfo=pytz.utc)
		else:
			return None

	def numCharactersInCleanedText(self):
		cleanedText = msg_util.cleanedReminder(msg_util.cleanedDoneCommand(self.chunk.normalizedTextWithoutTiming(self.user)))
		return len(cleanedText)

	# This could be a problem since it looks at now
	def isRecentAction(self):
		now = date_util.now(pytz.utc)

		lastActionTime = self.getLastActionTime(self.user)
		isRecentAction = True if (lastActionTime and (now - lastActionTime) < datetime.timedelta(minutes=5)) else False

		return isRecentAction

	def hasAnyNicety(self):
		return True if niceties.getNicety(self.chunk.originalText) else False

	def hasSilentNicety(self):
		nicety = niceties.getNicety(self.chunk.originalText)
		if nicety and nicety.isSilent():
			return True
		return False

	def nicetyMatchScore(self):
		nicety = niceties.getNicety(self.chunk.originalText)
		if nicety:
			return nicety.matchScore(self.chunk.originalText)
		return 0

	def inTutorial(self):
		return not self.user.isTutorialComplete()

	def startsWithHelpPhrase(self):
		return self.chunk.matches(self.help_re)

	def hasJokePhrase(self):
		return self.chunk.contains(self.jokeRequestRegex)

	def hasJokeFollowupPhrase(self):
		return self.chunk.contains(self.jokeFollowupRegex)

	def secondsSinceLastJoke(self):
		if self.user.getStateData(keeper_constants.LAST_JOKE_SENT_KEY):
			now = date_util.now(pytz.utc)
			lastJokeTime = datetime.datetime.utcfromtimestamp(self.user.getStateData(keeper_constants.LAST_JOKE_SENT_KEY)).replace(tzinfo=pytz.utc)
			return abs((lastJokeTime - now).total_seconds())
		else:
			return 10000000  # Big number to say its been a while

	# Returns True if this message has a valid time and it doesn't look like another remind command
	# If reminderSent is true, then we look for again or snooze which if found, we'll assume is a followup
	# Like "remind me again in 5 minutes"
	# If the message (without timing info) only is "remind me" then also is a followup due to "remind me in 5 minutes"
	# Otherwise False
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


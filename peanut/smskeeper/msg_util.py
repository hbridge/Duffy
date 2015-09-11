
import re
import logging
import unicodedata
import sys
import datetime
import humanize
import string
import pytz
import emoji

from models import Entry, Message
from smskeeper import keeper_constants, keeper_strings
from models import ZipData
from smskeeper.chunk import Chunk
import random

logger = logging.getLogger(__name__)


clear_re = re.compile("clear( (?P<label>.*))?", re.I)
freeform_fetch_res = [
	re.compile("what([']| i)s on (my )?#?(?P<label>[\S]+)( list)?", re.I),
	re.compile("#?(?P<label>[\S]+) list", re.I)
]
reminder_re = re.compile(
	"(can you )?#?remind(er|ers)? (me)?( to | on | at | in | by | about |)?"
	+ "|^i (need|want|have) to "
	+ "|^dont (let me )?forget (to )?"
	+ "|^do my "
	+ "|^add[: ]",
	re.I
)

# this is junk that sometimes get left in reminders and should be removed
reminder_cleanup_re = re.compile(r'every ?$|of ?$', re.I)
reminder_prefix_cleanup_re = re.compile(r'^(to|and|also)', re.I)
shared_reminder_cleanup_re = re.compile(r'^(text)', re.I)

# We have 2 name phrases, because in tutorial we want to support "I'm bob" but not normally...due to "I'm lonely"
tutorial_name_re = re.compile("(my name('s| is|s)|i('| a)m) (?P<name>[a-zA-Z\s]+)", re.I)
set_name_re = re.compile("my name('s| is|s) (?P<name>[a-zA-Z\s]+)", re.I)


done_re = re.compile(
	r"\b(done|clear|delete|remove|cancel|check .*off|check off|told|mark off|mark .*off|sent|cross .*off|checked|mailed|messaged|reviewed|took|created|turned in|put|gave|followed up|check it off|finished|talked|texted|txted|found|wrote|walked|worked|left|packed|cleaned|called|payed|paid|bought|did|picked|went|got|had|completed|cashed)\b",
	re.I)
delete_re = re.compile('delete (?P<indices>[0-9, ]+) ?(from )?(my )?#?(?P<label>[\S]+)?( list)?', re.I)
# we allow items to be blank to support "add to myphotolist" with an attached photo
freeform_add_re = re.compile("add ((?P<item>.+) )?to( my)? #?(?P<label>[^.!@#$%^&*()-=]+)( list)?", re.I)
handle_re = re.compile('@[a-zA-Z0-9]+\Z')

noOpWords = ["the", "hi", "nothing", "ok", "okay", "awesome", "great", "that's", "sounds", "good", "else", "thats", "that"]

REMINDER_FRINGE_TERMS = ["to", "on", "at", "in", "by", "please", "but"]

nonInterestingWords = [
	"sometime", "for", "please", "morning", "evening", "tonight", "today", "to", "this", "but", "i",
	"before", "after", "instead", "those", "things", "thing", "tonight", "today", "works", "better",
	"are", "my", "till", "until", "til", "actually", "do", "remind", "me", "please", "done", "snooze",
	"again", "all", "everything", "the", "every thing", "both", "im", "finally", "it", "i", "with", "ive",
	"already", "tasks", "keeper", "list", "that", "task", "all", "reminder", "reminders"]
nonInterestingWords.extend(noOpWords)
nonInterestingWords.extend(REMINDER_FRINGE_TERMS)

# These are words that are non-interesting for "dones", but can be interesting for things like create "cash check"
nonInterestingDoneWords = ["check", "off", "checkoff"]


def getInterestingWords(phrase, removeDones=False):
	interestingWords = list()
	for word in phrase.lower().split(' '):
		if word.lower() not in nonInterestingWords and word.lower() not in noOpWords:
			if word:  # Make sure the word isn't blank
				if removeDones and word in nonInterestingDoneWords:
					continue

				interestingWords.append(word)
	return interestingWords


def hasLabel(msg):
	for word in msg.split(' '):
		if isLabel(word):
			return True
	return False


def getLabel(msg):
	for word in msg.split(' '):
		if isLabel(word):
			return word
	return None


def isLabel(msg):
	stripedMsg = msg.strip()
	return (' ' in stripedMsg) is False and stripedMsg.startswith("#")

# from http://stackoverflow.com/questions/11066400/remove-punctuation-from-unicode-formatted-strings
punctuation_tbl = dict.fromkeys(
	i for i in xrange(sys.maxunicode)
	if unicodedata.category(unichr(i)).startswith('P')
)


# Lowercase
def cleanMsgText(msg):
	cleaned = msg.strip().lower()
	cleaned = cleaned.translate(punctuation_tbl)
	return cleaned


def isClearCommand(msg):
	return clear_re.match(msg) is not None


def getLabelToClear(msg):
	match = clear_re.match(msg)
	label = match.group("label").strip()
	if label[0] != ("#"):
		label = "#" + label
	return label


def isPickCommand(msg):
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'pick') or (isLabel(tokens[1]) and tokens[0].lower() == 'pick'))


def labelInFreeformFetch(msg):
	cleaned = msg.strip()
	for regex in freeform_fetch_res:
		match = regex.match(cleaned)
		if match:
			return "#" + match.group("label")  # the DB stores labels with the #
	return None


def labelInFetch(msg):
	label = labelInFreeformFetch(msg)
	if not label:
		label = msg
		if "#" not in label:
			label = "#" + msg
	return label


def isFetchCommand(msg, user):
	cleaned = msg.strip().lower()
	if isLabel(cleaned):
		return True
	elif labelInFreeformFetch(msg):
		return True
	elif isCommonListName(msg):
		return True
	else:
		entries = Entry.fetchEntries(user, "#%s" % cleanMsgText(msg), hidden=None)
		if entries.count() > 0:
			return True

	return False


def isCommonListName(msg):
	for reString in keeper_constants.COMMON_LIST_RES:
		if re.match(reString, msg) is not None:
			return True

	return False


def getPostalCode(msg):
	zipcodes = re.search(r'.*(\d{5}(\-\d{4})?)', msg)

	if zipcodes is not None:
		zipCode = str(zipcodes.groups()[0])
		logger.debug("Found zipcode: %s   from groups:  %s   and user entry: %s" % (zipCode, zipcodes.groups(), msg))
		return zipCode

	# regex from http://en.wikipedia.orgwikiUK_postcodes#Validation
	ukPostalCodes = re.search(r'\b([A-Z]{1,2}\d[A-Z\d]?)\b', msg.upper())

	if ukPostalCodes is not None:
		ukPostalCode = str(ukPostalCodes.groups()[0]).upper()
		logger.debug("Found uk code: %s" % ukPostalCode)
		return ukPostalCode

	return None


def dataForPostalCode(postalCode):
	zipDataResults = ZipData.objects.filter(postal_code=postalCode)

	if len(zipDataResults) == 0:
		logger.debug("Couldn't find db entry for %s" % postalCode)
		return (None, None, None)
	else:
		zipDataResult = zipDataResults[0]
		return (zipResultToTimeZone(zipDataResult), zipDataResult.wxcode, zipDataResult.temp_format)


def zipResultToTimeZone(zipDataResult):
	if zipDataResult.timezone == "PST":
		return pytz.timezone('US/Pacific')
	elif zipDataResult.timezone == "EST":
		return pytz.timezone('US/Eastern')
	elif zipDataResult.timezone == "CST":
		return pytz.timezone('US/Central')
	elif zipDataResult.timezone == "MST":
		if zipDataResult.state == 'AZ':
			return pytz.timezone('US/Arizona')
		else:
			return pytz.timezone('US/Mountain')
	elif zipDataResult.timezone == "PST-1":
		return pytz.timezone('US/Alaska')
	elif zipDataResult.timezone == "PST-2":
		return pytz.timezone('US/Hawaii')
	elif zipDataResult.timezone == "UTC":
		return pytz.utc
	else:
		return pytz.timezone(zipDataResult.timezone)


# Returns the msg without any punctuation, stripped of spaces and all lowercase
def simplifiedMsg(msg):
	newMsg = ''.join(ch for ch in msg if ch.isalnum() or ch == ' ')
	return cleanedMsg(newMsg.lower())


# Returns the msg lowercase and stripped of spaces and punc
def cleanedMsg(msg):
	return msg.strip(string.punctuation).strip().lower()


# Note: This does a very slow opperation by fetching all past messages
# of a classification then doing the comparison one at a time.
# This is done so we can run our "simplified msg" algo on each msg.  This might
# get slow going forward though if we get lots of classifications
def isMsgClassified(msg, classification):
	msgChunk = Chunk(msg)

	pastMessages = Message.getClassifiedAs(classification)
	for pastMessage in pastMessages:
		pastChunk = Chunk(pastMessage.getBody())
		if msgChunk.normalizedText() == pastChunk.normalizedText():
			return True

	return False


# TODO(Derek): Once we're all moved over to the new engine, move this into done.py
def isDoneCommand(msg):
	simpleMsg = simplifiedMsg(msg)

	# Note: Need a re search for done
	matches = done_re.search(simpleMsg) is not None
	if matches:
		return True

	return isMsgClassified(simpleMsg, keeper_constants.CLASS_COMPLETE_TODO_MOST_RECENT)


def isOkPhrase(msg):
	words = cleanedMsg(msg).split(' ')
	for word in words:
		if word in noOpWords:
			return True

	return False


def getFirstWord(msg):
	words = msg.split(' ')
	if len(words) > 0:
		firstWord = words[0].strip(string.punctuation).strip().lower()
		return firstWord
	else:
		return ""


# See if the first word is a 'no' or 'not' and is multiple words
def startsWithNo(msg):
	words = msg.split(' ')
	if len(words) > 1:
		firstWord = words[0].strip(string.punctuation).strip().lower()
		return firstWord in ["no", "not", "dont", "don't", "stop", "quit", "fuck"]
	return False


# Returns a string which doesn't have the "remind me" phrase in it
def cleanedReminder(msg, recurrence=None, shareHandles=None):
	cleaned = msg
	regexesToRemove = [reminder_re]

	# remove shared handles
	regexesToRemove.append(shared_reminder_cleanup_re)
	if shareHandles:
		for handle in shareHandles:
			cleaned = re.sub(handle, "", cleaned, flags=re.I)
			cleaned = cleaned.strip()

	# remove timing info etc
	if recurrence and recurrence is not keeper_constants.RECUR_ONE_TIME:
		# recur one-time doesn't have timing text that triggers it
		regexesToRemove.append(re.compile(keeper_constants.RECUR_REGEXES[recurrence], re.I))

	regexesToRemove.append(reminder_cleanup_re)
	regexesToRemove.append(reminder_prefix_cleanup_re)

	for regex in regexesToRemove:
		match = regex.search(cleaned)
		if match:
			cleaned = cleaned[:match.start()] + cleaned[match.end():]

	cleaned = cleaned.strip(string.punctuation).strip()
	words = cleaned.split(' ')
	if len(words) >= 2:
		if words[0].lower() in REMINDER_FRINGE_TERMS:
			cleaned = cleaned.split(' ', 1)[1]
		if words[-1].lower() in REMINDER_FRINGE_TERMS:
			cleaned = cleaned.rsplit(' ', 1)[0]

	# remove punctuation again after removing any fringe terms
	cleaned = cleaned.strip(string.punctuation).strip()

	# remove too many spaces
	cleaned = re.sub(r' {2,}', ' ', cleaned)

	return cleaned


# Returns a string which doesn't have the "done with" phrase in it
def cleanedDoneCommand(msg):
	match = done_re.search(msg.lower())
	if match:
		cleaned = msg[:match.start()] + msg[match.end():]
	else:
		cleaned = msg

	cleaned = cleaned.replace("with", "").strip(string.punctuation).strip()

	return cleaned


# Returns a string which doesn't have any "snooze" phrases in it
def cleanedSnoozeCommand(msg):
	cleaned = re.sub("(?i)snooze", "", msg)
	return cleaned


def nameInSetName(msg, tutorial=False):
	if tutorial:
		match = tutorial_name_re.match(msg.strip())
	else:
		match = set_name_re.match(msg.strip())

	if match:
		name = match.group('name')
		name = name.strip(string.punctuation)

		return name
	return None


# Returns a string which converts "my" to "your" and "i" to "you"
def warpReminderText(msg):
	i_words = re.compile(r'\bi ', re.IGNORECASE)
	warpedText = i_words.sub(r'you ', msg)

	my_words = re.compile(r'\bmy\b', re.IGNORECASE)
	warpedText = my_words.sub('your', warpedText)

	im_words = re.compile(r'\b(i\'m|im)\b', re.IGNORECASE)
	warpedText = im_words.sub('you\'re', warpedText)

	# Remove first word if its keeper. This is hacky and should be generalized in a routine
	# to clean up reminder text
	if getFirstWord(warpedText).lower() == "keeper":
		warpedText = ' '.join(warpedText.split(' ')[1:])

	if getFirstWord(warpedText).lower() == "that":
		warpedText = ' '.join(warpedText.split(' ')[1:])

	# Capitalize the first letter of the first word
	if len(warpedText) > 1:
		warpedText = warpedText[0].upper() + warpedText[1:]

	return warpedText.strip()


def isDeleteCommand(msg):
	return delete_re.match(msg) is not None


def isPrintHashtagsCommand(msg):
	cleaned = msg.strip().lower()
	return cleaned in ['#', '#hashtag', 'lists', 'my lists']


def isAddTextCommand(msg):
	if hasLabel(msg) and not isLabel(msg):
		return True
	else:
		match = freeform_add_re.match(cleanMsgText(msg))
		if match and match.group('item'):
			return True

	return False


def isHandle(msg):
	return handle_re.match(msg) is not None


def isFetchHandleCommand(msg):
	return isHandle(msg.strip())


def isMagicPhrase(msg):
	return 'trapper keeper' in msg.lower() or 'trapperkeeper' in msg.lower()


# Remove words from a msg
# So if starts out "hi there keeper" and list was "hi", returns "there keeper"
def removeWordsFromMsg(msg, wordsToRemove):
	wordsLeft = list()
	for word in msg.split(' '):
		if word.lower not in wordsToRemove:
			wordsLeft.append(word)
	return ' '.join(wordsLeft)


def removeNoOpWords(msg):
	return removeWordsFromMsg(msg, noOpWords)


# Returns the label that should be deleted from, and the item indices (as written) of
# the items to delete
def parseDeleteCommand(msg):
	match = delete_re.match(msg)
	# extract all indices
	requested_indices = set()
	for word in match.group('indices').split(' '):
		subwords = word.split(",")
		for subword in subwords:
			try:
				requested_indices.add(int(subword))
			except:
				pass

	# extract label
	label = match.group('label')
	if label:
		label = "#" + label
	return label, requested_indices


# Creates basic time string like:
#  9am
#  10:15pm
# This would be great to find a library to do
def getNaturalTime(time):
	after = before = ""
	if time.hour < 12:
		after = "am"
	else:
		after = "pm"

	if time.hour == 0:
		hourStr = "12"
	elif time.hour < 13:
		hourStr = str(time.hour)
	else:
		hourStr = str(time.hour - 12)

	if time.minute == 0:
		before = "%s" % hourStr
	else:
		before = "%s:%s" % (hourStr, time.strftime("%M"))

	return before + after


# Creates basic naturalized relative future time like:
# tomorrow at 4:15pm
# next Wed at 3pm
# This would be great to find a library to do
def naturalize(now, futureTime, includeTime=True):
	delta = futureTime - now
	deltaHours = delta.total_seconds() / 3600

	time = getNaturalTime(futureTime)
	dayOfWeek = futureTime.strftime("%a")
	monthName = futureTime.strftime("%B")

	evenTime = (futureTime.minute == 0 or futureTime.minute == 30)
	bindingWord = "by" if evenTime else "at"

	# If the same day, then say "today at 5pm"
	if deltaHours < 24 and futureTime.day == now.day:
		result = "later today"
		if includeTime:
			result += " %s %s" % (bindingWord, time)
	# Tomorrow
	elif (futureTime - datetime.timedelta(days=1)).date() == now.date():
		result = "tomorrow"
		if includeTime:
			result += " %s %s" % (bindingWord, time)
	elif delta.days < 7:
		result = "%s" % (dayOfWeek)
		if includeTime:
			result += " %s %s" % (bindingWord, time)
	elif delta.days < 14:
		result = "%s the %s" % (dayOfWeek, humanize.ordinal(futureTime.day))
	else:
		result = "%s %s" % (monthName, humanize.ordinal(futureTime.day))
	return result


# right now, just emojizes, could do more in the future, i.e. replace username etc
# returns the message text
def renderMsg(msg):
	return emoji.emojize(msg, use_aliases=True)


def renderDoneResponse(entries, isDelete):
	if len(entries) == 0:
		return None

	if len(entries) == 1:
		article = "that"
	elif len(entries) > 1:
		article = "those"

	if isDelete:
		msgBack = "Ok. Removed :ARTICLE: :cross_mark:"
	else:
		msgBack = "%s Checked :ARTICLE: off :white_check_mark:" % random.choice(keeper_strings.DONE_PHRASES)
	return msgBack.replace(':ARTICLE:', article)

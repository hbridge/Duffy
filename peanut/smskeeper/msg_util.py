import re
import phonenumbers
import logging
import unicodedata
import sys
import datetime
import humanize
import string
import pytz
import emoji

from models import Entry
from smskeeper import keeper_constants
from models import ZipData

logger = logging.getLogger(__name__)


clear_re = re.compile("clear( (?P<label>.*))?", re.I)
freeform_fetch_res = [
	re.compile("what([']| i)s on (my )?#?(?P<label>[\S]+)( list)?", re.I),
	re.compile("#?(?P<label>[\S]+) list", re.I)
]
reminder_re = re.compile(
	"(can you )?#?remind(er|ers)? (?P<handle>[a-zA-Z]+)( to | on | at | in | by | about |)?"
	+ "|i (need|want|have) to "
	+ "|dont (let me )?forget (to )?"
	+ "|do my ",
	re.I
)
done_re = re.compile(r"\b(done|check off|check it off|finished|talked|texted|txted|found|wrote|walked|worked|left|packed|cleaned|called|payed|paid|bought|did|picked|went|got|had|completed)\b", re.I)
delete_re = re.compile('delete (?P<indices>[0-9, ]+) ?(from )?(my )?#?(?P<label>[\S]+)?( list)?', re.I)
# we allow items to be blank to support "add to myphotolist" with an attached photo
freeform_add_re = re.compile("add ((?P<item>.+) )?to( my)? #?(?P<label>[^.!@#$%^&*()-=]+)( list)?", re.I)
handle_re = re.compile('@[a-zA-Z0-9]+\Z')

# We have 2 name phrases, because in tutorial we want to support "I'm bob" but not normally...due to "I'm lonely"
tutorial_name_re = re.compile("(my name('s| is|s)|i('| a)m) (?P<name>[a-zA-Z\s]+)", re.I)
set_name_re = re.compile("my name('s| is|s) (?P<name>[a-zA-Z\s]+)", re.I)

stop_re = re.compile(r"stop$|cancel( keeper)?$|leave me alone|stop .+ me|.*don't text me.*", re.I)

noOpWords = ["the", "hi", "nothing", "ok", "okay", "awesome", "great", "that's", "sounds", "good", "else", "thats", "that"]

REMINDER_FRINGE_TERMS = ["to", "on", "at", "in", "by"]

nonInterestingWords = ["morning", "evening", "tonight", "today", "to", "this", "but", "i", "before", "after", "instead", "those", "things", "thing", "tonight", "today", "works", "better", "are", "my", "till", "until", "til", "actually", "do", "remind", "me", "please", "done", "snooze", "again", "all", "everything", "check", "off", "checkoff", "the", "every thing", "both", "im", "finally", "it", "i", "with", "ive", "already", "tasks", "keeper", "list", "that", "task", "all"]


def getInterestingWords(phrase):
	interestingWords = list()
	for word in phrase.lower().split(' '):
		if word.lower() not in nonInterestingWords and word.lower() not in noOpWords:
			if word:  # Make sure the word isn't blank
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


def isDigestCommand(msg):
	return re.match("(what('s| is) on my )?(todo(s)?|task(s)?)( list)?$|what do i have to do today|tasks for today", msg, re.I) is not None


def isCommonListName(msg):
	for reString in keeper_constants.COMMON_LIST_RES:
		if re.match(reString, msg) is not None:
			return True

	return False


def isSetZipcodeCommand(msg):
	return re.match("my zip ?code is (\d{5}(\-\d{4})?)", msg, re.I) is not None


def getZipcode(msg):
	postalCodes = re.search(r'.*(\d{5}(\-\d{4})?)', msg)

	if postalCodes is None:
		return None

	zipCode = str(postalCodes.groups()[0])
	logger.debug("Found zipcode: %s   from groups:  %s   and user entry: %s" % (zipCode, postalCodes.groups(), msg))
	return zipCode


def timezoneForZipcode(zipCode):
	zipDataResults = ZipData.objects.filter(zip_code=zipCode)

	if len(zipDataResults) == 0:
		logger.debug("Couldn't find db entry for %s" % zipCode)
		return None
	else:
		return zipResultToTimeZone(zipDataResults[0])


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


# Returns the msg without any punctuation, stripped of spaces and all lowercase
def simplifiedMsg(msg):
	newMsg = ''.join(ch for ch in msg if ch.isalnum() or ch == ' ')
	return cleanedMsg(newMsg.lower())


# Returns the msg lowercase and stripped of spaces and punc
def cleanedMsg(msg):
	return msg.strip(string.punctuation).strip().lower()

tipRE = re.compile('.*send me tips')
def isSetTipFrequencyCommand(msg):
	return not hasLabel(msg) and tipRE.match(msg.strip().lower())


def isRemindCommand(msg):
	return (reminder_re.search(msg.lower()) is not None)


def isOkPhrase(msg):
	words = cleanedMsg(msg).split(' ')
	for word in words:
		if word in noOpWords:
			return True

	return False


def isDoneCommand(msg):
	simpleMsg = simplifiedMsg(msg)
	# First look with local regex
	if (done_re.search(simpleMsg) is not None):
		return True

	"""
	# Then look in db
	for word in msg.lower().split(' '):
		word = word.strip(string.punctuation).strip()
		dbWords = VerbData.objects.filter(Q(past=word) | Q(past_participle=word))
		if len(dbWords) > 0:
			return True
	"""


def isSnoozeCommand(msg):
	return re.match("snooze", msg, re.I) is not None

def getFirstWord(msg):
	words = msg.split(' ')
	if len(words) > 0:
		firstWord = words[0].strip(string.punctuation).strip().lower()
		return firstWord
	else:
		return ""


def isQuestion(msg):
	firstWord = getFirstWord(msg)
	if isRemindCommand(msg):
		return False
	return ("?" in msg) or firstWord in ["who", "what", "where", "when", "why", "how", "what's", "whats", "is", "are"]


# See if the first word is a 'no' or 'not' and is multiple words
def startsWithNo(msg):
	words = msg.split(' ')
	if len(words) > 1:
		firstWord = words[0].strip(string.punctuation).strip().lower()
		return firstWord in ["no", "not", "cancel", "dont", "don't", "stop", "quit", "fuck"]
	return False


def getReminderHandle(msg):
	text = msg.lower()
	match = reminder_re.search(text)
	if match:
		handle = match.group("handle")
		if handle not in REMINDER_FRINGE_TERMS:
			return handle
	return None


# Returns a string which doesn't have the "remind me" phrase in it
def cleanedReminder(msg):
	match = reminder_re.search(msg.lower())
	if match:
		cleaned = msg[:match.start()] + msg[match.end():]
	else:
		cleaned = msg

	cleaned = cleaned.strip(string.punctuation).strip()
	words = cleaned.split(' ')
	if len(words) >= 2:
		if words[0].lower() in REMINDER_FRINGE_TERMS:
			cleaned = cleaned.split(' ', 1)[1]
		if words[-1].lower() in REMINDER_FRINGE_TERMS:
			cleaned = cleaned.rsplit(' ', 1)[0]

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


# Returns a string which converts "my" to "your" and "i" to "you"
def warpReminderText(msg):
	i_words = re.compile(r'\bi\b', re.IGNORECASE)
	warpedText = i_words.sub(r'you', msg)

	my_words = re.compile(r'\bmy\b', re.IGNORECASE)
	warpedText = my_words.sub('your', warpedText)

	return warpedText.strip()


def isDeleteCommand(msg):
	return delete_re.match(msg) is not None


def isHelpCommand(msg):
	cleaned = cleanMsgText(msg)
	return re.match('[?]$|huh$|help$|what$|how do.* work|what.* (can|do) you do|tell me more', cleaned) is not None


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


def hasPhoneNumber(msg):
	matches = phonenumbers.PhoneNumberMatcher(msg, 'US')
	return matches.has_next()
	# foundMatch = True
	# obj.phone_number = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)


def isPhoneNumber(msg):
	matches = phonenumbers.PhoneNumberMatcher(msg, 'US')
	if not matches.has_next():
		return False
	match = matches.next()
	return match.start == 0 and match.end == len(msg)

	return matches.has_next()


def extractPhoneNumbers(msg):
	matches = phonenumbers.PhoneNumberMatcher(msg, 'US')
	remaining_str = unicode(msg)
	phone_numbers = []
	for match in matches:
		formatted = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)
		if formatted:
			phone_numbers.append(formatted)
			logger.debug("removing %s in %s" % (match.raw_string, remaining_str))
			remaining_str = remaining_str.replace(match.raw_string, "")

	return phone_numbers, remaining_str


def isStopCommand(msg):
	return stop_re.match(msg) is not None


def isCreateHandleCommand(msg):
	phoneNumbers, remaining_str = extractPhoneNumbers(msg)
	return (
		isHandle(remaining_str.strip())
		and phoneNumbers is not None
		and len(phoneNumbers) > 0
	)


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


# Returns back (textWithoutLabel, label, listOfHandles)
def getMessagePieces(msg):
	textWithoutLabel, label, listOfHandles, listOfUrls, dictOfUrlTypes = getMessagePiecesWithMedia(msg, {})
	return (textWithoutLabel, label, listOfHandles)


# Returns back (textWithoutLabel, label, listOfHandles, listOfUrls, dictOfURLsToTypes)
# Text could have comma's in it, that is dealt with later
def getMessagePiecesWithMedia(msg, requestDict):
	# process text
	nonLabels = list()
	handleList = list()
	label = None

	# first check whether it maches our freeform add
	match = freeform_add_re.match(msg)
	if match:
		label = "#" + match.group('label')
		if label.endswith(" list"):
			label = label[:-len(" list")]
		if match.group("item"):
			nonLabels = match.group('item').split(" ")
	else:
		# otherwise pick out pieces
		for word in msg.split(' '):
			if isLabel(word):
				label = word
			elif isHandle(word):
				handleList.append(word)
			else:
				nonLabels.append(word)

	# process media
	mediaUrlList = list()
	mediaUrlTypes = dict()

	if 'NumMedia' in requestDict:
		numMedia = int(requestDict['NumMedia'])
	else:
		numMedia = 0

	for n in range(numMedia):
		urlParam = 'MediaUrl' + str(n)
		typeParam = 'MediaContentType' + str(n)
		url = requestDict[urlParam]
		urlType = requestDict[typeParam]
		mediaUrlList.append(url)
		mediaUrlTypes[url] = urlType

	return (' '.join(nonLabels), label, handleList, mediaUrlList, mediaUrlTypes)


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
	deltaHours = delta.seconds / 3600

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
	elif (futureTime - datetime.timedelta(days=1)).day == now.day:
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

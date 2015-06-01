import re
import phonenumbers
import logging
import unicodedata
import sys
import datetime
import humanize
import string
import pytz

from models import Entry
from smskeeper import keeper_constants
from models import ZipData


logger = logging.getLogger(__name__)


clear_re = re.compile("clear( (?P<label>.*))?", re.I)
freeform_fetch_res = [
	re.compile("what([']| i)s on (my )?#?(?P<label>[\S]+)( list)?", re.I),
	re.compile("#?(?P<label>[\S]+) list", re.I)
]
reminder_re = re.compile("#?remind(er|ers)? (?P<handle>[a-zA-Z]+)( to)?(: )?", re.I)
delete_re = re.compile('delete (?P<indices>[0-9, ]+) ?(from )?(my )?#?(?P<label>[\S]+)?( list)?', re.I)
# we allow items to be blank to support "add to myphotolist" with an attached photo
freeform_add_re = re.compile("add ((?P<item>.+) )?to( my)? #?(?P<label>[^.!@#$%^&*()-=]+)( list)?", re.I)
handle_re = re.compile('@[a-zA-Z0-9]+\Z')

# We have 2 name phrases, because in tutorial we want to support "I'm bob" but not normally...due to "I'm lonely"
tutorial_name_re = re.compile("(my name('s| is|s)|i('| a)m) (?P<name>[a-zA-Z\s]+)", re.I)
set_name_re = re.compile("my name('s| is|s) (?P<name>[a-zA-Z\s]+)", re.I)

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
punctuation_tbl = dict.fromkeys(i for i in xrange(sys.maxunicode)
	if unicodedata.category(unichr(i)).startswith('P'))


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


def isSetZipcodeCommand(msg):
	return re.match("my zip ?code is (\d{5}(\-\d{4})?)", msg, re.I) is not None


def timezoneForMsg(msg):
	postalCodes = re.search(r'.*(\d{5}(\-\d{4})?)', msg)

	if postalCodes is None:
		logger.debug("postalCodes were none for: %s" % msg)
		return None, "Sorry, I didn't understand that, what's your zipcode?"

	zipCode = str(postalCodes.groups()[0])
	logger.debug("Found zipcode: %s   from groups:  %s   and user entry: %s" % (zipCode, postalCodes.groups(), msg))
	zipDataResults = ZipData.objects.filter(zip_code=zipCode)

	if len(zipDataResults) == 0:
		logger.debug("Couldn't find db entry for %s" % zipCode)
		return None, "Sorry, I don't know that zipcode. Please try again"
	else:
		return zipResultToTimeZone(zipDataResults[0]), None

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


tipRE = re.compile('.*send me tips')
def isSetTipFrequencyCommand(msg):
	return not hasLabel(msg) and tipRE.match(msg.strip().lower())


def isRemindCommand(msg):
	text = msg.lower()
	return (reminder_re.search(text) is not None)


def getReminderHandle(msg):
	text = msg.lower()
	match = reminder_re.search(text)
	return match.group("handle")


def isDeleteCommand(msg):
	return delete_re.match(msg) is not None


def isHelpCommand(msg):
	cleaned = cleanMsgText(msg)
	return re.match('[?]$|huh$|help$|what$|how do you work|what.* (can|do) you do|tell me more', cleaned) is not None

def isPrintHashtagsCommand(msg):
	cleaned = msg.strip().lower()
	return cleaned == '#' or cleaned == '#hashtag' or cleaned == '#hashtags'


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
	return 'cancel' == msg.lower() or 'stop' == msg.lower()


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
def naturalize(now, futureTime):
	delta = futureTime - now
	deltaHours = delta.seconds / 3600

	time = getNaturalTime(futureTime)
	dayOfWeek = futureTime.strftime("%a")

	# If the same day, then say "today at 5pm"
	if deltaHours < 24 and futureTime.day == now.day:
		return "later today around %s" % time
	# Tomorrow
	elif (futureTime - datetime.timedelta(days=1)).day == now.day:
		return "tomorrow around %s" % time
	elif delta.days < 6:
		return "%s around %s" % (dayOfWeek, time)

	return "%s the %s" % (dayOfWeek, humanize.ordinal(futureTime.day))

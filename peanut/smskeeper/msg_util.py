import re
import phonenumbers
import logging
import unicodedata
import sys
import datetime

from models import Entry
from smskeeper import keeper_constants
from models import ZipData


logger = logging.getLogger(__name__)


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

clear_re = re.compile("clear (?P<label>.*)", re.I)
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

freeform_fetch_res = [
	re.compile("what([']| i)s on (my )?#?(?P<label>[\S]+)( list)?", re.I),
	re.compile("#?(?P<label>[\S]+) list", re.I)
]

def labelInFreeformFetch(msg):
	cleaned = msg.strip()
	for regex in freeform_fetch_res:
		match = regex.match(cleaned)
		if match:
			return "#" + match.group("label")  # the DB stores labels with the #
	return None

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
		return zipDataResults[0].timezone, None

tipRE = re.compile('send me tips')
def isSetTipFrequencyCommand(msg):
	return not hasLabel(msg) and tipRE.match(msg.strip().lower())


get_reminders_re = re.compile("#?remind( me|me|er|ers)?( to)?(: )?", re.I)
def isRemindCommand(msg):
	text = msg.lower()
	return (
		'#remind' in text or
		'#remindme' in text or
		'#reminder' in text or
		'#reminders' in text or
		get_reminders_re.match(text) is not None
	)


delete_re = re.compile('delete [0-9]+')
def isDeleteCommand(msg):
	return delete_re.match(msg.lower()) is not None

def isHelpCommand(msg):
	cleaned = cleanMsgText(msg)
	return re.match('huh$|what$|how do you work|what (can|do) you do', cleaned) is not None or msg == "?"


def isPrintHashtagsCommand(msg):
	cleaned = msg.strip().lower()
	return cleaned == '#' or cleaned == '#hashtag' or cleaned == '#hashtags'

# we allow items to be blank to support "add to myphotolist" with an attached photo
freeform_add_re = re.compile("add ((?P<item>.+) )?to( my)? #?(?P<label>[^.!@#$%^&*()-=]+)( list)?", re.I)
def isAddTextCommand(msg):
	if hasLabel(msg) and not isLabel(msg):
		return True
	else:
		match = freeform_add_re.match(cleanMsgText(msg))
		if match and match.group('item'):
			return True

	return False

def isTellMeMore(msg):
	cleaned = msg.strip().lower()
	return "tell me more" in cleaned or "what else can you do" in cleaned


handle_re = re.compile('@[a-zA-Z0-9]+\Z')
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


def nameInTutorialPrompt(msg):
	match = re.match("(my name('| i)s|i('| a)m) (?P<name>[a-zA-Z\s]+)", msg, re.I)
	if match:
		return match.group('name')
	return None

set_name_re = re.compile("my name('| i)s (?P<name>[a-zA-Z\s]+)", re.I)

def nameInSetName(msg):
	match = set_name_re.match(msg.strip())
	if match:
		return match.group('name')
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

	# If the same day, then say "today at 5pm"
	if deltaHours < 24 and futureTime.day == now.day:
		return "today at %s" % getNaturalTime(futureTime)
	# Tomorrow
	elif (futureTime - datetime.timedelta(days=1)).day == now.day:
		return "tomorrow at %s" % getNaturalTime(futureTime)
	elif delta.days < 6:
		return "%s at %s" % (futureTime.strftime("%a"), getNaturalTime(futureTime))
	elif delta.days < 13:
		return "next %s at %s" % (futureTime.strftime("%a"), getNaturalTime(futureTime))

	return "%s days from now" % delta.days

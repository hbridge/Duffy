import re
import phonenumbers
import logging
import unicodedata
import sys

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

def isClearCommand(msg):
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'clear') or (isLabel(tokens[1]) and tokens[0].lower() == 'clear'))


def isPickCommand(msg):
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'pick') or (isLabel(tokens[1]) and tokens[0].lower() == 'pick'))


def isFetchCommand(msg):
	return isLabel(msg)


tipRE = re.compile('send me tips')
def isSetTipFrequencyCommand(msg):
	return not hasLabel(msg) and tipRE.match(msg.strip().lower())


def isRemindCommand(msg):
	text = msg.lower()
	return (
		'#remind' in text or
		'#remindme' in text or
		'#reminder' in text or
		'#reminders' in text or
		re.match('remind me', text) is not None
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


def isAddCommand(msg):
	return hasLabel(msg) and not isLabel(msg)

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
	return isHandle(remaining_str.strip())


def isMagicPhrase(msg):
	return 'trapper keeper' in msg.lower() or 'trapperkeeper' in msg.lower()


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

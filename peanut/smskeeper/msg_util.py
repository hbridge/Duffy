import re
import phonenumbers

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
	return (' ' in stripedMsg) == False and stripedMsg.startswith("#")

def isNicety(msg):
	return msg.strip().lower() in ["hi", "hello", "thanks", "thank you"]

def isClearCommand(msg):
	stripedMsg = msg.strip()
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'clear') or (isLabel(tokens[1]) and tokens[0].lower()=='clear'))

def isPickCommand(msg):
	stripedMsg = msg.strip()
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'pick') or (isLabel(tokens[1]) and tokens[0].lower()=='pick'))

def isFetchCommand(msg):
	return isLabel(msg)
	
def isRemindCommand(msg):
	text = msg.lower()
	return ('#remind' in text or
		   '#remindme' in text or
		   '#reminder' in text or
		   '#reminders' in text)

delete_re = re.compile('delete [0-9]+')
def isDeleteCommand(msg):
	return delete_re.match(msg.lower()) is not None

def isActivateCommand(msg):
	return '#activate' in msg.lower()

def isHelpCommand(msg):
	return msg.strip().lower() == 'huh?'

def isPrintHashtagsCommand(msg):
	cleaned = msg.strip().lower()
	return  cleaned == '#hashtag' or cleaned == '#hashtags'

def isAddCommand(msg):
	return hasLabel(msg) and not isLabel(msg)

handle_re = re.compile('@[a-zA-Z0-9]+\Z')
def isHandle(msg):
	return handle_re.match(msg) is not None



def hasPhoneNumber(msg):
	matches = phonenumbers.PhoneNumberMatcher(msg, 'US')
	return matches.has_next()
	# foundMatch = True
	# obj.phone_number = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)

def extractPhoneNumbers(msg):
	matches = phonenumbers.PhoneNumberMatcher(msg, 'US')
	phone_numbers = []
	for match in matches:
		formatted = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)
		if formatted: phone_numbers.append(formatted)
	return phone_numbers
	
def isCreateHandleCommand(msg):
	words = msg.strip().split(' ')

	hasHandle = False
	for word in words:
		if isHandle(word): hasHandle = True

	return len(words) == 2 and hasHandle and hasPhoneNumber(msg)

def isMagicPhrase(msg):
	return 'trapper keeper' in msg.lower()


# Returns back (textWithoutLabel, label, listOfHandles)
def getMessagePieces(msg):
	textWithoutLabel, label, listOfUrls, listOfHandles = getMessagePiecesWithMedia(msg, 0, {})
	return (textWithoutLabel, label, listOfHandles)

# Returns back (textWithoutLabel, label, listOfUrls, listOfHandles)
# Text could have comma's in it, that is dealt with later
def getMessagePiecesWithMedia(msg, numMedia, requestDict):
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

	for n in range(numMedia):
		param = 'MediaUrl' + str(n)
		mediaUrlList.append(requestDict[param])
		#TODO need to store mediacontenttype as well.

	#TODO use a separate process but probably this is not the right place to do it.
	#if numMedia > 0:
	#	mediaUrlList = image_util.moveMediaToS3(mediaUrlList)
	return (' '.join(nonLabels), label, mediaUrlList, handleList)




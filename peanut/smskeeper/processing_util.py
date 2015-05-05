import re
import phonenumbers
import logging

from smskeeper import keeper_constants
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

COMMAND_FUNCS = {keeper_constants.COMMAND_PICK: isPickCommand,
				 keeper_constants.COMMAND_CLEAR: isClearCommand,
				 keeper_constants.COMMAND_FETCH: isFetchCommand,
				 keeper_constants.COMMAND_ADD: isAddCommand,
				 keeper_constants.COMMAND_REMIND: isRemindCommand,
				 keeper_constants.COMMAND_DELETE: isDeleteCommand,
				 keeper_constants.COMMAND_ACTIVATE: isActivateCommand,
				 keeper_constants.COMMAND_LIST: isPrintHashtagsCommand,
				 keeper_constants.COMMAND_HELP: isHelpCommand,
				}

def getPossibleCommands(msg):
	commandList = list()
	for key, func in COMMAND_FUNCS.iteritems():
		if func(msg):
			commandList.append(key)
	return commandList

def getStateMachine(user):
	fsm = getFsm(user.state)
	return fsm

def processMessage(phoneNumber, msg, numMedia, requestDict, keeperNumber):
	try:
		user = User.objects.get(phone_number=phoneNumber)
	except User.DoesNotExist:
		user = User.objects.create(phone_number=phoneNumber)
		dealWithNonActivatedUser(user, True, keeperNumber)
		return
	finally:
		Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True)

	fn = stateCallbacks[user.state]
	fn(user, msg, numMedia, requestDict, keeperNumber)

def processNormalState(user, msg, numMedia, requestDict, keeperNumber):
	# Figure out what kind of command this looks like
	pass


def processTutorialState(user, msg, numMedia, requestDict, keeperNumber):
	# Process based on tutorial_step
	pass
	
def processNotActivatedState(user, msg, numMedia, requestDict, keeperNumber):
	# No matter what, return string back
	pass

def processRemindState(user, msg, numMedia, requestDict, keeperNumber):
	# If this looks like a time string, get time and assign to last remind command
	# Otherwise, move to normal state
	pass

def processDeleteState(user, msg, numMedia, requestDict, keeperNumber):
	# If this looks like a delete command, grab last label message and process
	# Otherwise, move to normal state
	pass

def processAddState(user, msg, numMedia, requestDict, keeperNumber):
	# If this looks like a label, then assign to last item from unassigned
	# Otherwise, move to normal state
	pass

stateCallbacks = {
					'normal': processNormalState,
					'tutorial': processTutorialState,
					'not-activated': processNotActivatedState,
					'remind': processRemindState,
					'delete': processDeleteState,
					'add': processAddState,
}


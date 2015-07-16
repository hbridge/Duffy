import random
import re
import logging
import time

from smskeeper.models import Entry, Message

from smskeeper import sms_util, msg_util, reminder_util
from smskeeper import actions, keeper_constants
from smskeeper import async


logger = logging.getLogger(__name__)


def getPreviousMessage(user):
	# Normally would sort by added but unit tests barf since they get added at same time
	# Here, sorting by id should accomplish the same goal
	msgs = Message.objects.filter(user=user, incoming=True).order_by("-id")[:2]

	if len(msgs) == 2:
		return msgs[1]
	else:
		return None


def dealWithPrintHashtags(user, keeperNumber):
	# print out all of the active hashtags for the account
	listText = ""
	labels = Entry.fetchAllLabels(user)
	if len(labels) == 0:
		listText = "You don't have anything tagged. Yet."
	for label in labels:
		entries = Entry.fetchEntries(user=user, label=label)
		if len(entries) > 0:
			listText += "%s (%d)\n" % (label, len(entries))

	sms_util.sendMsg(user, listText, None, keeperNumber)


def dealWithCreateHandle(user, msg, keeperNumber):
	phoneNumbers, remaining_str = msg_util.extractPhoneNumbers(msg)
	phoneNumber = phoneNumbers[0]

	words = remaining_str.strip().split(' ')
	handle = None
	for word in words:
		if msg_util.isHandle(word):
			handle = word
			break

	contact, didCreateUser, oldUser = actions.createHandle(user, handle, phoneNumber)

	if oldUser is not None:
		if oldUser.phone_number == phoneNumber:
			sms_util.sendMsg(user, "%s is already set to %s" % (handle, phoneNumber), None, keeperNumber)
		else:
			sms_util.sendMsg(user, "%s is now set to %s (used to be %s)" % (handle, phoneNumber, oldUser.phone_number), None, keeperNumber)
	else:
		sms_util.sendMsg(user, "%s is now set to %s" % (handle, phoneNumber), None, keeperNumber)


def dealWithAdd(user, msg, requestDict, keeperNumber):
	# if this is the first time they have added a label other than reminders, tell them about fetching it
	if (Entry.objects.filter(creator=user).exclude(label=keeper_constants.REMIND_LABEL).count() == 0):
		firstListItem = True
	else:
		firstListItem = False
	entries, unresolvedHandles = actions.add(user, msg, requestDict, keeperNumber, True, True)

	label = entries[0].label
	if firstListItem:
		sms_util.sendMsg(user, "Just type '%s' to get these back" % (label.replace("#", "")), None, keeperNumber)
	else:
		if keeper_constants.isRealKeeperNumber(keeperNumber):
			time.sleep(1)
		actions.fetch(user, label, keeperNumber)
		user.setState(keeper_constants.STATE_IMPLICIT_LABEL)
		user.setStateData(keeper_constants.IMPLICIT_LABEL_STATE_DATA_KEY, label)

	if len(unresolvedHandles) > 0:
		user.setState(keeper_constants.STATE_UNRESOLVED_HANDLES)
		user.setStateData(keeper_constants.ENTRY_IDS_DATA_KEY, map(lambda entry: entry.id, entries))
		user.setStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY, unresolvedHandles)
		user.save()
		return False, None

	return True, None


def dealWithTodoProductMsg(user, msg, requestDict, keeperNumber):
	nattyResult = reminder_util.getNattyResult(user, msg)
	if msg_util.isRemindCommand(msg):
		logger.info("User %s: I think '%s' is a remind command" % (user.id, msg))
		user.setState(keeper_constants.STATE_REMIND)
		return False, None  # Reprocess
	# Hacky, theres a lot of exception cases here
	elif msg_util.isDoneCommand(msg) and not nattyResult.validTime():
		logger.info("User %s: I think '%s' is a done command" % (user.id, msg))
		msgSent, isAll = actions.done(user, msg, keeperNumber)
		classification = keeper_constants.CLASS_COMPLETE_TODO_ALL if isAll else keeper_constants.CLASS_COMPLETE_TODO_SPECIFIC
		return True, classification
	elif msg_util.isSnoozeCommand(msg):
		logger.info("User %s: I think '%s' is a snooze command" % (user.id, msg))
		actions.snooze(user, msg, keeperNumber)
		return True, keeper_constants.CLASS_SNOOZE
	elif msg_util.isDigestCommand(msg):
		logger.info("User %s: I think '%s' is a digest command" % (user.id, msg))
		if "today" in msg.lower():
			async.sendDigestForUserId(user.id, keeperNumber)
		else:
			async.sendAllRemindersForUserId(user.id, keeperNumber)
		return True, keeper_constants.CLASS_FETCH_DIGEST
	elif len(msg.split(' ')) <= 1:
		logger.info("User %s: I think '%s' is a single word, skipping" % (user.id, msg))
		return True, keeper_constants.CLASS_SILENT_NICETY
	else:
		logger.info("User %s: I think '%s' is something else so doing remind state" % (user.id, msg))
		user.setState(keeper_constants.STATE_REMIND)
		return False, None  # Reprocess


#   Main logic for processing a message
#   Pulled out so it can be called either from sms code or command line
def process(user, msg, requestDict, keeperNumber):
	if "NumMedia" in requestDict:
		numMedia = int(requestDict["NumMedia"])
	else:
		numMedia = 0

	try:
		if re.match("yippee ki yay motherfucker", msg):
			raise NameError("intentional exception")
		if user.product_id == keeper_constants.TODO_PRODUCT_ID:
			return dealWithTodoProductMsg(user, msg, requestDict, keeperNumber)

		# Below here is legacy stuff, lists, pictures
		# STATE_REMIND
		elif msg_util.isRemindCommand(msg) and not msg_util.isClearCommand(msg) and not msg_util.isFetchCommand(msg, user):
			logger.info("User %s: I think '%s' is a remind command" % (user.id, msg))
			# TODO  Fix this state so the logic isn't so complex
			user.setState(keeper_constants.STATE_REMIND)
			user.save()
			# Reprocess
			return False, keeper_constants.CLASS_CREATE_TODO
		# STATE_NORMAL
		elif msg_util.isPrintHashtagsCommand(msg):
			logger.info("User %s: I think '%s' is a print hashtags command" % (user.id, msg))
			# this must come before the isLabel() hashtag fetch check or we will try to look for a #hashtags list
			dealWithPrintHashtags(user, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isFetchCommand(msg, user) and numMedia == 0:
			logger.info("User %s: I think '%s' is a fetch command" % (user.id, msg))
			label = msg_util.labelInFetch(msg)
			actions.fetch(user, label, keeperNumber)
			user.setState(keeper_constants.STATE_IMPLICIT_LABEL)
			user.setStateData(keeper_constants.IMPLICIT_LABEL_STATE_DATA_KEY, label)
		# STATE_NORMAL
		elif msg_util.isClearCommand(msg) and numMedia == 0:
			logger.info("User %s: I think '%s' is a clear command" % (user.id, msg))
			label = msg_util.getLabelToClear(msg)
			actions.clear(user, label, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isPickCommand(msg) and numMedia == 0:
			logger.info("User %s: I think '%s' is a pick command" % (user.id, msg))
			label = msg_util.getLabel(msg)
			actions.pickItemFromLabel(user, label, keeperNumber)
		# STATE_ADD
		elif msg_util.isFetchHandleCommand(msg):
			logger.info("User %s: I think '%s' is a fetch handle command" % (user.id, msg))
			actions.fetchHandle(user, msg, keeperNumber)
		elif msg_util.isCreateHandleCommand(msg):
			logger.info("User %s: I think '%s' is a create handle command" % (user.id, msg))
			dealWithCreateHandle(user, msg, keeperNumber)
		# STATE_DELETE
		elif msg_util.isDeleteCommand(msg):
			logger.info("User %s: I think '%s' is a delete command" % (user.id, msg))
			label, indices = msg_util.parseDeleteCommand(msg)
			actions.deleteIndicesFromLabel(user, label, indices, keeperNumber)
			user.setState(keeper_constants.STATE_IMPLICIT_LABEL)
			user.setStateData(keeper_constants.IMPLICIT_LABEL_STATE_DATA_KEY, label)
		elif msg_util.isAddTextCommand(msg) or numMedia > 0:
			logger.info("User %s: I think '%s' is a add text command" % (user.id, msg))
			return dealWithAdd(user, msg, requestDict, keeperNumber)
		else:  # catch all, we're not sure
			return dealWithTodoProductMsg(user, msg, requestDict, keeperNumber)

		return True, None
	except:
		logger.warning("User %s: and msg '%s' got exception" % (user.id, msg))
		sms_util.sendMsg(user, random.choice(keeper_constants.GENERIC_ERROR_MESSAGES), None, keeperNumber)
		raise

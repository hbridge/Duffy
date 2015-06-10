import random
import re
import logging

from smskeeper.models import Entry, Message

from smskeeper import sms_util, msg_util
from smskeeper import actions, keeper_constants
from smskeeper import niceties

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

	if firstListItem:
		sms_util.sendMsg(user, "Just type '%s' to get these back" % (entries[0].label.replace("#", "")), None, keeperNumber)

	if len(unresolvedHandles) > 0:
		user.setState(keeper_constants.STATE_UNRESOLVED_HANDLES)
		user.setStateData(keeper_constants.ENTRY_IDS_DATA_KEY, map(lambda entry: entry.id, entries))
		user.setStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY, unresolvedHandles)
		user.save()
		return False

	return True


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
		# STATE_REMIND
		elif msg_util.isRemindCommand(msg) and not msg_util.isClearCommand(msg) and not msg_util.isFetchCommand(msg, user):
			logger.debug("For user %s I think '%s' is a remind command" % (user.id, msg))
			# TODO  Fix this state so the logic isn't so complex
			user.setState(keeper_constants.STATE_REMIND)
			user.save()
			# Reprocess
			return False
		# STATE_NORMAL
		elif msg_util.isPrintHashtagsCommand(msg):
			logger.debug("For user %s I think '%s' is a print hashtags command" % (user.id, msg))
			# this must come before the isLabel() hashtag fetch check or we will try to look for a #hashtags list
			dealWithPrintHashtags(user, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isFetchCommand(msg, user) and numMedia == 0:
			logger.debug("For user %s I think '%s' is a fetch command" % (user.id, msg))
			label = msg_util.labelInFetch(msg)
			actions.fetch(user, label, keeperNumber)
			user.setState(
				keeper_constants.STATE_IMPLICIT_LABEL,
				stateData={keeper_constants.IMPLICIT_LABEL_STATE_DATA_KEY: label}
			)
		# STATE_NORMAL
		elif msg_util.isClearCommand(msg) and numMedia == 0:
			logger.debug("For user %s I think '%s' is a clear command" % (user.id, msg))
			label = msg_util.getLabelToClear(msg)
			actions.clear(user, label, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isPickCommand(msg) and numMedia == 0:
			logger.debug("For user %s I think '%s' is a pick command" % (user.id, msg))
			label = msg_util.getLabel(msg)
			actions.pickItemFromLabel(user, label, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isHelpCommand(msg):
			logger.debug("For user %s I think '%s' is a help command" % (user.id, msg))
			actions.help(user, msg, keeperNumber)
		elif msg_util.isSetTipFrequencyCommand(msg):
			logger.debug("For user %s I think '%s' is a set tip frequency command" % (user.id, msg))
			actions.setTipFrequency(user, msg, keeperNumber)
		# STATE_ADD
		elif msg_util.isFetchHandleCommand(msg):
			logger.debug("For user %s I think '%s' is a fetch handle command" % (user.id, msg))
			actions.fetchHandle(user, msg, keeperNumber)
		elif msg_util.isCreateHandleCommand(msg):
			logger.debug("For user %s I think '%s' is a create handle command" % (user.id, msg))
			dealWithCreateHandle(user, msg, keeperNumber)
		# STATE_DELETE
		elif msg_util.isDeleteCommand(msg):
			logger.debug("For user %s I think '%s' is a delete command" % (user.id, msg))
			label, indices = msg_util.parseDeleteCommand(msg)
			actions.deleteIndicesFromLabel(user, label, indices, keeperNumber)
			user.setState(
				keeper_constants.STATE_IMPLICIT_LABEL,
				stateData={keeper_constants.IMPLICIT_LABEL_STATE_DATA_KEY: label}
			)
		elif msg_util.isAddTextCommand(msg) or numMedia > 0:
			logger.debug("For user %s I think '%s' is a add text command" % (user.id, msg))
			return dealWithAdd(user, msg, requestDict, keeperNumber)
		else:  # catch all, we're not sure
			if user.product_id == 1:
				if msg_util.isDoneCommand(msg):
					logger.debug("User %s: (product id 1) I think '%s' is a done command" % (user.id, msg))
					actions.done(user, msg, keeperNumber)
				elif msg_util.isQuestion(msg):
					logger.debug("User %s: (product id 1) I think '%s' is a question" % (user.id, msg))
					actions.unknown(user, msg, keeperNumber)
				elif len(msg.split(' ')) <= 1:
					logger.debug("User %s: (product id 1) I think '%s' is a single word, skipping" % (user.id, msg))
				else:
					logger.debug("For user %s (product id 1) I think '%s' is something else so doing remind state" % (user.id, msg))
					user.setState(keeper_constants.STATE_REMIND)
					user.save()
					return False  # Reprocess
			# there's no label or media, and we don't know what to do with this, send generic info and put user in unknown state
			else:
				actions.unknown(user, msg, keeperNumber)

		return True
	except:
		logger.warning("For user %s and msg '%s' got exception" % (user.id, msg))
		sms_util.sendMsg(user, random.choice(keeper_constants.GENERIC_ERROR_MESSAGES), None, keeperNumber)
		raise

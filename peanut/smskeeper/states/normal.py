import random
import re
import logging
import datetime
import pytz

from django.conf import settings

from smskeeper.models import Entry, Message

from smskeeper import sms_util, msg_util, helper_util
from smskeeper import actions, keeper_constants
from smskeeper import niceties

from common import slack_logger

from peanut.settings import constants

logger = logging.getLogger(__name__)


def getPreviousMessage(user):
	# Normally would sort by added but unit tests barf since they get added at same time
	# Here, sorting by id should accomplish the same goal
	msgs = Message.objects.filter(user=user, incoming=True).order_by("-id")[:2]

	if len(msgs) == 2:
		return msgs[1]
	else:
		return None


def getInferredLabel(user):
	# Normally would sort by added but unit tests barf since they get added at same time
	# Here, sorting by id should accomplish the same goal
	incoming_messages = Message.objects.filter(user=user, incoming=True).order_by("-id")
	if len(incoming_messages) < 2:
		return None

	for i in range(1, len(incoming_messages)):
		msg_body = incoming_messages[i].getBody()
		logger.info("message -%d: %s" % (i, msg_body))
		if msg_util.isLabel(msg_body):
			return msg_body
		elif msg_util.isDeleteCommand(msg_body):
			continue
		else:
			return None

	return None


def dealWithDelete(user, msg, keeperNumber):
	words = msg.strip().lower().split(" ")
	words.remove("delete")
	# what remains in words could be ["1"], ["1,2"], ["1,", "2"] etc.
	requested_indices = set()
	for word in words:
		subwords = word.split(",")
		logger.debug("word, subwords: %s, %s" % (word, subwords))
		for subword in subwords:
			try:
				requested_indices.add(int(subword))
			except:
				pass
	logger.debug("requested indices: %s" % requested_indices)
	item_indices = map(lambda x: x - 1, requested_indices)

	item_indices = sorted(item_indices, reverse=True)
	logger.debug(item_indices)

	label = None
	if msg_util.hasLabel(msg):
		text, label, handles = msg_util.getMessagePieces(msg)
	else:
		label = getInferredLabel(user)

	if label:
		entries = Entry.fetchEntries(user=user, label=label)
		out_of_range = list()
		deleted_texts = list()
		if entries is None:
			helper_util.sendNotFoundMessage(user, label, keeperNumber)
			return
		for item_index in item_indices:
			if item_index < 0 or item_index >= len(entries):
				out_of_range.append(item_index)
				continue
			entry = entries[item_index]
			entry.hidden = True
			entry.save()
			if entry.text:
				deleted_texts.append(entry.text)
			else:
				deleted_texts.append("item " + str(item_index+1))

		if len(deleted_texts) > 0:
			if len(deleted_texts) > 1:
				retMsg = "%d items" % len(deleted_texts)
			else:
				retMsg = "'%s'" % (deleted_texts[0])
			sms_util.sendMsg(user, 'Ok, I deleted %s' % (retMsg), None, keeperNumber)
		if len(out_of_range) > 0:
			out_of_range_string = ", ".join(map(lambda x: str(x + 1), out_of_range))
			sms_util.sendMsg(user, 'Can\'t delete %s in %s' % (out_of_range_string, label), None, keeperNumber)
		actions.fetch(user, label, keeperNumber)
	else:
		sms_util.sendMsg(user, 'Sorry, I\'m not sure which hashtag you\'re referring to. Try "delete [number] [hashtag]"', None, keeperNumber)


def dealWithPrintHashtags(user, keeperNumber):
	#print out all of the active hashtags for the account
	listText = ""
	labels = Entry.fetchAllLabels(user)
	if len(labels) == 0:
		listText = "You don't have anything tagged. Yet."
	for label in labels:
		entries = Entry.fetchEntries(user=user, label=label)
		if len(entries) > 0:
			listText += "%s (%d)\n" % (label, len(entries))

	sms_util.sendMsg(user, listText, None, keeperNumber)


def pickItemForUserLabel(user, label, keeperNumber):
	entries = Entry.fetchEntries(user=user, label=label)
	if len(entries) == 0:
		helper_util.sendNotFoundMessage(user, label, keeperNumber)
		return

	entry = random.choice(entries)
	if entry.img_url:
		sms_util.sendMsg(user, "My pick for %s:" % label, None, keeperNumber)
		sms_util.sendMsg(user, entry.text, entry.img_url, keeperNumber)
	else:
		sms_util.sendMsg(user, "My pick for %s: %s" % (label, entry.text), None, keeperNumber)


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
			# TODO  Fix this state so the logic isn't so complex
			user.setState(keeper_constants.STATE_REMIND)
			user.save()
			# Reprocess
			return False
		# STATE_NORMAL
		elif msg_util.isPrintHashtagsCommand(msg):
			# this must come before the isLabel() hashtag fetch check or we will try to look for a #hashtags list
			dealWithPrintHashtags(user, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isFetchCommand(msg, user) and numMedia == 0:
			actions.fetch(user, msg, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isClearCommand(msg) and numMedia == 0:
			actions.clear(user, msg, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isPickCommand(msg) and numMedia == 0:
			label = msg_util.getLabel(msg)
			pickItemForUserLabel(user, label, keeperNumber)
		# STATE_NORMAL
		elif msg_util.isHelpCommand(msg):
			actions.help(user, msg, keeperNumber)
		elif msg_util.isSetTipFrequencyCommand(msg):
			actions.setTipFrequency(user, msg, keeperNumber)
		elif msg_util.isTellMeMore(msg):
			actions.tellMeMore(user, msg, keeperNumber)
		# STATE_ADD
		elif msg_util.isCreateHandleCommand(msg):
			dealWithCreateHandle(user, msg, keeperNumber)
		# STATE_DELETE
		elif msg_util.isDeleteCommand(msg):
			dealWithDelete(user, msg, keeperNumber)
		elif msg_util.nameInSetName(msg):
			actions.setName(user, msg, keeperNumber)
		elif msg_util.isSetZipcodeCommand(msg):
			actions.setZipcode(user, msg, keeperNumber)
		elif msg_util.isAddTextCommand(msg) or numMedia > 0:
			return dealWithAdd(user, msg, requestDict, keeperNumber)
		else:  # catch all, it's a nicety or an error
			nicety = niceties.getNicety(msg)
			if nicety:
				response = nicety.getResponse()
				if response:
					sms_util.sendMsg(user, nicety.getResponse(), None, keeperNumber)

			# there's no label or media, and we don't know what to do with this, send generic info and put user in unknown state
			else:
				now = datetime.datetime.now(pytz.timezone("US/Eastern"))
				if now.hour >= 9 and now.hour <= 22 and keeperNumber != constants.SMSKEEPER_TEST_NUM and not settings.DEBUG:
					user.setState(keeper_constants.STATE_PAUSED)
					user.save()
					postMsg = "User %s paused after: %s" % (user.id, msg)
					slack_logger.postManualAlert(user, postMsg, keeperNumber, keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)
					logger.info("Putting user %s into paused state due to the message %s" % (user.id, msg))
					return True
				else:
					sms_util.sendMsg(user, random.choice(keeper_constants.UNKNOWN_COMMAND_PHRASES), None, keeperNumber)
					user.setState(keeper_constants.STATE_UNKNOWN_COMMAND)
					user.save()

		return True
	except:
		sms_util.sendMsg(user, random.choice(keeper_constants.GENERIC_ERROR_MESSAGES), None, keeperNumber)
		raise

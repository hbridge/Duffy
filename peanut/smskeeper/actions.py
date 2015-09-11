import random
import pytz
import logging
import datetime
import json

from smskeeper import sms_util, msg_util, helper_util, image_util, user_util
from smskeeper import keeper_constants, keeper_strings
from smskeeper.models import Entry, Contact, User
from smskeeper import analytics

from common import slack_logger, date_util

logger = logging.getLogger(__name__)


def fetch(user, label, keeperNumber):
	if label is None or label == "":
		raise NameError("label is blank")

	# We support many different remind commands, but every one actually does REMIND_LABEL
	entries = Entry.fetchEntries(user=user, label=label)
	clearMsg = "\n\nYou can say 'clear' to clear or 'delete NUMBER' to delete an item.\nManage lists at %s" % (user.getWebAppURL())
	mediaUrls = list()

	if len(entries) == 0:
		helper_util.sendNotFoundMessage(user, label, keeperNumber)
		return

	currentMsg = "%s:" % label.replace("#", "")

	count = 1
	for entry in entries:
		if entry.img_url:
			mediaUrls.append(entry.img_url)
		else:
			otherUsers = list(entry.users.all())
			otherUsers.remove(user)
			otherUserHandles = list()
			for otherUser in otherUsers:
				# see if the user has a contact, if so use the handle
				contacts = Contact.objects.filter(user=user, target=otherUser)
				if len(contacts) > 0:
					otherUserHandles.append(contacts[0].handle)
				else:
					otherUserHandles.append(otherUser.phone_number)

			otherUsersString = ""
			if len(otherUserHandles) > 0:
				otherUsersString = "(%s)" % (", ".join(otherUserHandles))

			newStr = str(count) + ". " + entry.text + " " + otherUsersString

			if entry.remind_timestamp:
				if entry.remind_timestamp > date_util.now(pytz.utc):
					localNow = date_util.now(user.getTimezone())
					futureTime = entry.remind_timestamp.astimezone(user.getTimezone())
					newStr = "%s %s" % (newStr, msg_util.naturalize(localNow, futureTime))

			currentMsg = currentMsg + "\n " + newStr
			count += 1

	if len(mediaUrls) > 0:
		if (len(mediaUrls) > 1):
			photoPhrase = " photos"
		else:
			photoPhrase = " photo"

		currentMsg = currentMsg + "\n +" + str(len(mediaUrls)) + photoPhrase + " coming separately"

		gridImageUrl = image_util.generateImageGridUrl(mediaUrls)

		sms_util.sendMsg(user, currentMsg + clearMsg, None, keeperNumber)
		sms_util.sendMsg(user, '', gridImageUrl, keeperNumber)
	else:
		sms_util.sendMsg(user, currentMsg + clearMsg, None, keeperNumber)

	analytics.logUserEvent(
		user,
		"Fetched Label",
		{
			"Entry Count": len(entries),
			"Label": label,
			"Media Count": len(mediaUrls)
		}
	)


def clear(user, label, keeperNumber):
	entries = Entry.fetchEntries(user=user, label=label)
	if len(entries) == 0:
		helper_util.sendNotFoundMessage(user, label, keeperNumber)
	else:
		for entry in entries:
			entry.hidden = True
			entry.save()
		sms_util.sendMsg(user, "%s cleared" % (label.replace("#", "")), None, keeperNumber)

	analytics.logUserEvent(
		user,
		"Cleared Label",
		{
			"Entry Count": len(entries),
			"Label": label,
		}
	)


def createHandle(user, handle, targetNumber):
	# see if there's an existing contact for that handle
	oldUser = None
	createdUser = False
	try:
		contact = Contact.objects.get(user=user, handle=handle)
		oldUser = contact.target
		if (oldUser.phone_number == targetNumber):
			return oldUser
	except Contact.DoesNotExist:
		contact = None

	# get and set the new target user, creating if necessary
	try:
		target_user = User.objects.get(phone_number=targetNumber)
	except User.DoesNotExist:
		target_user = user_util.createUser(
			targetNumber,
			json.dumps({
				"source": "sharedReminder",
				"referer": user.id
			}),
			user.getKeeperNumber(),
			user.product_id,
			None,
			isShare=True
		)
		createdUser = True

	if contact is not None:
		contact.target = target_user
	else:
		contact = Contact.objects.create(user=user, handle=handle, target=target_user)
	contact.save()

	analytics.logUserEvent(
		user,
		"Resolved Handle",
		{
			"Did create user": createdUser,
		}
	)

	return contact, createdUser, oldUser


def fetchHandle(user, msg, keeperNumber):
	handle = msg.strip()
	try:
		contact = Contact.objects.get(user=user, handle__iexact=handle)
		sms_util.sendMsg(user, "I have %s's number down as %s" % (handle, contact.target.phone_number), None, keeperNumber)
	except Contact.DoesNotExist:
		sms_util.sendMsg(
			user,
			"I don't have %s's phone number. To teach me, say %s with the phone number, like '%s (555) 555-5555'" % (handle, handle, handle),
			None,
			keeperNumber
		)


def pickItemFromLabel(user, label, keeperNumber):
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


def deleteIndicesFromLabel(user, label, indices, keeperNumber):
	if label:
		# subtract 1 from indices because userland is 1-indexed, but it's stored 0-indexed
		indices = map(lambda x: x - 1, indices)
		# reverse sort before we start deleting
		indices = sorted(indices, reverse=True)

		entries = Entry.fetchEntries(user=user, label=label)
		out_of_range = list()
		deleted_texts = list()
		if entries is None:
			helper_util.sendNotFoundMessage(user, label, keeperNumber)
			return
		for item_index in indices:
			if item_index < 0 or item_index >= len(entries):
				out_of_range.append(item_index)
				continue
			entry = entries[item_index]
			entry.hidden = True
			entry.save()
			if entry.text:
				deleted_texts.append(entry.text)
			else:
				deleted_texts.append("item " + str(item_index + 1))

		if len(deleted_texts) > 0:
			if len(deleted_texts) > 1:
				retMsg = "%d items" % len(deleted_texts)
			else:
				retMsg = "'%s'" % (deleted_texts[0])
			sms_util.sendMsg(user, 'Ok, I deleted %s' % (retMsg), None, keeperNumber)
		if len(out_of_range) > 0:
			out_of_range_string = ", ".join(map(lambda x: str(x + 1), out_of_range))
			sms_util.sendMsg(user, 'Can\'t delete %s in %s' % (out_of_range_string, label), None, keeperNumber)

		# do a fetch at the end to reprint the list
		fetch(user, label, keeperNumber)
	else:
		sms_util.sendMsg(user, 'Sorry, I\'m not sure which list you\'re referring to. Try "delete NUMBER from list"', None, keeperNumber)


def clearAll(entries):
	# Assume this is done, or done with and clear all
	if len(entries) > 1:
		msgBack = u"Nice! Checked those off "
	else:
		msgBack = u"Nice! Checked that off "

	for entry in entries:
		msgBack += u"\u2705"
		entry.hidden = True
		entry.save()
	return msgBack


def updateDigestTime(user, chunk):
	if "never" in chunk.normalizedText() or "stop" in chunk.normalizedText():
		user.digest_state = keeper_constants.DIGEST_STATE_LIMITED
		user.save()

		logger.debug("User %s: Updated digest state to limited due to user request" % (user.id))

		sms_util.sendMsg(user, keeper_strings.CONFIRM_MORNING_DIGEST_LIMITED_STATE_TEXT)
	else:
		nattyResult = chunk.getNattyResult(user)

		if not nattyResult:
			logger.error("User %s: Just tried to set new digest time but msg '%s' didn't have any time info in it" % (user.id, chunk.originalText))
			return False

		tzAwareTime = nattyResult.utcTime.astimezone(user.getTimezone())

		# Make sure we're doing an am hour...since natty result will probably be pm
		if "pm" not in chunk.originalText and tzAwareTime.hour > 12:
			tzAwareTime = tzAwareTime + datetime.timedelta(hours=12)

		user.digest_hour = tzAwareTime.hour
		user.digest_minute = tzAwareTime.minute

		user.save()

		logger.debug("User %s: Updated digest time to %s %s due to user request" % (user.id, user.digest_hour, user.digest_minute))

		sms_util.sendMsg(user, keeper_strings.CHANGE_MORNING_DIGEST_TIME_TEXT % (msg_util.getNaturalTime(tzAwareTime)))
	return True


def unknown(user, msg, keeperNumber, unknownType, sendMsg=True, doPause=False, doAlert=False):
	now = date_util.now(pytz.timezone("US/Eastern"))

	user.messageWasUnknown = True

	if now.hour >= 9 and now.hour <= 22 and keeperNumber != keeper_constants.SMSKEEPER_CLI_NUM:
		infoMessage = "User %s: unknown '%s'" % (user.id, msg)
		if doAlert or doPause:
			infoMessage += "   @derek @aseem @henry"  # Add ourselves to get alerted during the day

		if doPause:
			user_util.setPaused(user, True, keeperNumber, infoMessage)

		slack_logger.postManualAlert(user, infoMessage, keeperNumber, keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)

		logger.info("User %s: (During day) I couldn't figure out '%s'. unknown type %s" % (user.id, msg, unknownType))
		ret = True
	else:
		if sendMsg:
			sms_util.sendMsg(user, random.choice(keeper_strings.UNKNOWN_COMMAND_PHRASES), None, keeperNumber)
			logger.info("User %s: (At night) I couldn't figure out '%s'" % (user.id, msg))
		slack_logger.postManualAlert(
			user,
			"User %s: sent unknown %s" % (user.id, msg),
			keeperNumber,
			keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS
		)
		ret = False

	analytics.logUserEvent(
		user,
		"Sent Unknown Command",
		{
			"Command": msg,
			"Paused": user.isPaused(),
		}
	)
	return ret

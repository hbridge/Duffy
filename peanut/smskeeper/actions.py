import random
import pytz
import logging

from smskeeper import sms_util, msg_util, helper_util, image_util, user_util, entry_util, reminder_util
from smskeeper import keeper_constants
import django

from smskeeper.models import Entry, Contact, User
from smskeeper import analytics

from common import slack_logger, date_util, weather_util
from django.conf import settings

logger = logging.getLogger(__name__)


def shareEntries(user, entries, handles, keeperNumber):
	sharedHandles = list()
	notFoundHandles = list()
	if not isinstance(entries, django.db.models.query.QuerySet) and not isinstance(entries, list):
		raise TypeError("entries must be list or django.db.models.query.QuerySet, actual type: %s" % (type(entries)))
	if not isinstance(handles, list):
		raise TypeError("handles must be a list, actual type: %s" % (type(handles)))
	for handle in handles:
		contact = Contact.fetchByHandle(user, handle)
		if contact is None:
			notFoundHandles.append(handle)
		else:
			# add the target user to the entry and send them a message
			sharedHandles.append(handle)
			for entry in entries:
				entry.users.add(contact.target)

			shareText = None
			if len(entries) == 1:
				shareText = "%s shared \"%s %s\" with you." % (user.nameOrPhone(), entry.text, entry.label)
			else:
				shareText = "%s shared %d items tagged %s with you." % (user.nameOrPhone(), len(entries), entry.label)

			if len(contact.target.getMessages(incoming=False)) == 0:  # this is a new user, send them special text.
				user_util.activate(contact.target, "Hi there. %s" % (shareText), None, keeperNumber)
			else:
				sms_util.sendMsg(contact.target, "Ding ding! %s" % (shareText), None, keeperNumber)
	return sharedHandles, notFoundHandles


def add(user, msg, requestDict, keeperNumber, sendResponse, parseCommas):
	text, label, handles, originalMedia, mediaToTypes = msg_util.getMessagePiecesWithMedia(msg, requestDict)
	autoLabels = set()

	# TODO use a separate process but probably this is not the right place to do it.
	if len(originalMedia) > 0:
		# only move media if we're not running a test or using CLI
		if keeper_constants.isTestKeeperNumber(keeperNumber):
			s3mediaUrls = originalMedia
		else:
			s3mediaUrls = image_util.moveMediaToS3(originalMedia)

	createdEntries = list()

	if len(originalMedia) == 0:
		# Text comes back without label but still has commas. Split on those here
		if parseCommas:
			for entryText in text.split(','):
				entryText = entryText.strip()
				if len(entryText) > 0:
					if label is None:
						raise NameError("Cannot add text without a label")
					entry = Entry.createEntry(user, keeperNumber, label, entryText)
					createdEntries.append(entry)
		else:
			entry = Entry.createEntry(user, keeperNumber, label, text)
			createdEntries.append(entry)
	else:
		for i, entryMediaUrl in enumerate(originalMedia):
			entry_label = label
			if entry_label is None or label == "":
				entry_label = "#attachment"
				mediaType = mediaToTypes[originalMedia[i]]
				if mediaType == "image/jpeg":
					entry_label = keeper_constants.PHOTO_LABEL
				elif mediaType == "image/png":
					entry_label = keeper_constants.SCREENSHOT_LABEL
				autoLabels.add(entry_label)

			# create the entry with the s3 url instead of
			entry = Entry.createEntry(user, keeperNumber, entry_label, text=text, img_url=s3mediaUrls[i])
			createdEntries.append(entry)

	sharedHandles = list()
	notFoundHandles = list()
	shareString = ""
	if len(handles) > 0:
		sharedHandles, notFoundHandles = shareEntries(user, createdEntries, handles, keeperNumber)
	if len(sharedHandles) > 0:
		shareString = "  I also shared that with %s" % ", ".join(sharedHandles)

	if sendResponse:
		if len(autoLabels) > 0:
			sms_util.sendMsg(user, "Filing that under your %s list.%s" % (", ".join(autoLabels), shareString), None, keeperNumber)
		else:
			sms_util.sendMsg(user, helper_util.randomAcknowledgement() + shareString, None, keeperNumber)

	if label != keeper_constants.REMIND_LABEL:  # reminders logged separately
		analytics.logUserEvent(
			user,
			"Added Entries",
			{
				"Entry Count": len(createdEntries),
				"Share Count": len(handles),
				"Label": label,
				"Media Count": len(originalMedia)
			}
		)

	return createdEntries, notFoundHandles


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


def createHandle(user, handle, targetNumber, initialState=None):
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
		target_user = User.objects.create(phone_number=targetNumber)
		if initialState:
			target_user.setState(initialState)
		target_user.save()
		createdUser = True

	if contact is not None:
		contact.target = target_user
	else:
		contact = Contact.objects.create(user=user, handle=handle, target=target_user)
	contact.save()

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


def unknown(user, msg, keeperNumber, sendMsg=True):
	postMsg = "User %s paused after: '%s'" % (user.id, msg)

	now = date_util.now(pytz.timezone("US/Eastern"))
	if now.hour >= 9 and now.hour <= 22 and keeperNumber != keeper_constants.SMSKEEPER_CLI_NUM:
		postMsg += "   @derek @aseem @henry"  # Add ourselves to get alerted during the day
		user.paused = True
		user.last_paused_timestamp = date_util.now(pytz.utc)
		user.save()
		logger.info("User %s: Putting into paused state due to the message %s" % (user.id, msg))
		ret = True
	else:
		if sendMsg:
			sms_util.sendMsg(user, random.choice(keeper_constants.UNKNOWN_COMMAND_PHRASES), None, keeperNumber)
			user.setState(keeper_constants.STATE_UNKNOWN_COMMAND)
			user.save()
			logger.info("User %s: (At night) I couldn't figure out '%s'" % (user.id, msg))
		ret = False

	slack_logger.postManualAlert(user, postMsg, keeperNumber, keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)

	analytics.logUserEvent(
		user,
		"Sent Unknown Command",
		{
			"Command": msg,
			"Paused": user.isPaused(),
		}
	)
	return ret

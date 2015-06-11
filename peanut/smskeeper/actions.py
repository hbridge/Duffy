import random
import datetime
import pytz
import logging
from fuzzywuzzy import fuzz

from smskeeper import sms_util, msg_util, helper_util, image_util, user_util
from smskeeper import keeper_constants
import django

from smskeeper.models import Entry, Contact, User
from smskeeper import analytics

from common import slack_logger
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
	if msg_util.isRemindCommand(label):
		label = keeper_constants.REMIND_LABEL
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
				if entry.remind_timestamp > datetime.datetime.now(pytz.utc):
					localNow = datetime.datetime.now(user.getTimezone())
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


def setTipFrequency(user, msg, keeperNumber):
	old_tip_frequency = user.tip_frequency_days
	if "weekly" in msg:
		user.tip_frequency_days = 7
		user.save()
		sms_util.sendMsg(user, "Ok, I'll send you tips weekly.", None, keeperNumber)
	elif "monthly" in msg:
		user.tip_frequency_days = 30
		user.save()
		sms_util.sendMsg(user, "Ok, I'll send you tips monthly.", None, keeperNumber)
	elif "daily" in msg:
		user.tip_frequency_days = 1
		user.save()
		sms_util.sendMsg(user, "Ok, I'll send you tips daily.", None, keeperNumber)
	elif "never" in msg or "stop" in msg or "don't" in msg:
		user.tip_frequency_days = 0
		user.save()
		sms_util.sendMsg(user, "Ok, I'll stop sending you tips.", None, keeperNumber)
	else:
		sms_util.sendMsg(user, "Sorry, I didn't get that. You can type 'send me tips weekly/monthly/never' to change how often I send you tips.", None, keeperNumber)

	analytics.logUserEvent(
		user,
		"Changed Tip Frequency",
		{
			"Old Frequency": old_tip_frequency,
			"New Frequency": user.tip_frequency_days,
		}
	)


def help(user, msg, keeperNumber):
	sms_util.sendMsgs(user, keeper_constants.HELP_MESSAGES, keeperNumber)
	analytics.logUserEvent(
		user,
		"Requested Help",
		{
			"Message": msg.lower()
		}
	)

	user.setState(keeper_constants.STATE_HELP)


def setName(user, msg, keeperNumber):
	name = msg_util.nameInSetName(msg)
	if name and name != "":
		user.name = name
		user.save()
		sms_util.sendMsg(user, "Great, I'll call you %s from now on." % name, None, keeperNumber)
	else:
		sms_util.sendMsg(user, "Sorry, I didn't catch that, try saying something like 'My name is Keeper'" % name, None, keeperNumber)
	analytics.logUserEvent(
		user,
		"Changed Name",
		None
	)


def setZipcode(user, msg, keeperNumber):
	timezone, user_error = msg_util.timezoneForMsg(msg)
	if timezone is None:
		sms_util.sendMsg(user, user_error, None, keeperNumber)
		return True

	user.timezone = timezone
	user.save()
	sms_util.sendMsg(user, helper_util.randomAcknowledgement(), None, keeperNumber)

	analytics.logUserEvent(
		user,
		"Changed Zipcode",
		None
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


# Deal with a nicety message
# Might respond with something, might not
def nicety(user, nicety, requestDict, keeperNumber):
	response = nicety.getResponse(user, requestDict, keeperNumber)
	if response:
		sms_util.sendMsg(user, response, None, keeperNumber)

	# log that the user sent a nicety regardless of whether Keeper responds
	analytics.logUserEvent(
		user,
		"Sent Nicety",
		None
	)


def getBestEntryMatch(user, msg, entries=None):
	if not entries:
		entries = Entry.objects.filter(creator=user, label="#reminders", hidden=False)

	logger.debug("User %s: Going to try to find the best match to '%s'" % (user.id, msg))
	entries = sorted(entries, key=lambda x: x.added)

	bestMatch = None
	bestScore = 0

	for entry in entries:
		score = fuzz.token_set_ratio(entry.text, msg)
		if score > bestScore:
			logger.debug("User %s: Message %s got score %s, higher than best of %s. New Best" % (user.id, entry.text, score, bestScore))
			bestMatch = entry
			bestScore = score
		else:
			logger.debug("User %s: Message %s got score %s, lower than best of %s" % (user.id, entry.text, score, bestScore))

	logger.debug("User %s: Decided on best match of %s to '%s' with score %s" % (user.id, bestMatch.text, msg, bestScore))
	return (bestMatch, bestScore)


def done(user, msg, keeperNumber):
	bestMatch, score = getBestEntryMatch(user, msg)

	if score > 50:
		bestMatch.hidden = True
		bestMatch.save()

		logger.info("User %s: Done got msg '%s' and decided to hide entry '%s' (%s) due to score of %s" % (user.id, msg, bestMatch.text, bestMatch.id, score))

		msgBack = u"Nice. %s  \u2705" % bestMatch.text
		sms_util.sendMsg(user, msgBack, None, keeperNumber)
	else:

		logger.info("User %s: Done got msg '%s' and only got best score of %s with match '%s' (%s)" % (user.id, msg, score, bestMatch.text, bestMatch.id))

		msgBack = "Sorry, I'm not sure which entry you mean"
		sms_util.sendMsg(user, msgBack, None, keeperNumber)


def unknown(user, msg, keeperNumber):
	now = datetime.datetime.now(pytz.timezone("US/Eastern"))
	if now.hour >= 9 and now.hour <= 22 and keeperNumber != keeper_constants.SMSKEEPER_TEST_NUM and not settings.DEBUG:
		user.paused = True
		user.save()
		postMsg = "User %s paused after: '%s'   @derek @aseem @henry" % (user.id, msg)
		slack_logger.postManualAlert(user, postMsg, keeperNumber, keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)
		logger.info("Putting user %s into paused state due to the message %s" % (user.id, msg))
	else:
		sms_util.sendMsg(user, random.choice(keeper_constants.UNKNOWN_COMMAND_PHRASES), None, keeperNumber)
		user.setState(keeper_constants.STATE_UNKNOWN_COMMAND)
		user.save()
		logger.info("For user %s I couldn't figure out '%s'" % (user.id, msg))
	analytics.logUserEvent(
		user,
		"Sent Unknown Command",
		{
			"Command": msg,
			"Paused": user.isPaused(),
		}
	)


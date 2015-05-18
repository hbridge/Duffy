import humanize
import time

from smskeeper import sms_util, msg_util, helper_util, image_util, user_util
from smskeeper import keeper_constants
import django

from smskeeper.models import Entry, Contact, User


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
		media = image_util.moveMediaToS3(originalMedia)

	createdEntries = list()

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

		entry = Entry.createEntry(user, keeperNumber, entry_label, text=None, img_url=entryMediaUrl)
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
			sms_util.sendMsg(user, "Filing that under " + ", ".join(autoLabels) + shareString, None, keeperNumber)
		else:
			sms_util.sendMsg(user, helper_util.randomAcknowledgement() + shareString, None, keeperNumber)

	return createdEntries, notFoundHandles


def fetch(user, msg, keeperNumber):
	# This is a label fetch.  See if a note with that label exists then return
	cleaned = msg.strip().lower()
	if len(cleaned.split(" ")) == 1:
		label = msg
		if "#" not in label:
			label = "#" + msg
	else:
		label = msg_util.labelInFreeformFetch(msg)
	if label is None or label == "":
		raise NameError("label is blank")

	# We support many different remind commands, but every one actually does REMIND_LABEL
	if msg_util.isRemindCommand(label):
		label = keeper_constants.REMIND_LABEL
	entries = Entry.fetchEntries(user=user, label=label)
	clearMsg = "\n\nSend 'clear %s' to clear or 'delete [number]' to delete an item."%(label)
	mediaUrls = list()

	if len(entries) == 0:
		helper_util.sendNotFoundMessage(user, label, keeperNumber)
		return

	currentMsg = "%s:" % label

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
				dt = entry.remind_timestamp.replace(tzinfo=None)
				newStr = "%s %s" % (newStr, humanize.naturaltime(dt))
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

def clear(user, msg, keeperNumber):
	label = msg_util.getLabel(msg)
	entries = Entry.fetchEntries(user=user, label=label)
	if len(entries) == 0:
		helper_util.sendNotFoundMessage(user, label, keeperNumber)
	else:
		for entry in entries:
			entry.hidden = True
			entry.save()
		sms_util.sendMsg(user, "%s cleared"% (label), None, keeperNumber)

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
		target_user = User.objects.create(phone_number=targetNumber)
		target_user.save()
		createdUser = True

	if contact is not None:
		contact.target = target_user
	else:
		contact = Contact.objects.create(user=user, handle=handle, target=target_user)
	contact.save()

	return contact, createdUser, oldUser


def setTipFrequency(user, msg, keeperNumber):
	words = msg.strip().lower().split(" ")
	if words[3] == "weekly":
		user.tip_frequency_days = 7
		user.save()
		sms_util.sendMsg(user, "Ok, I'll send you tips weekly.", None, keeperNumber)
	elif words[3] == "monthly":
		user.tip_frequency_days = 30
		user.save()
		sms_util.sendMsg(user, "Ok, I'll send you tips monthly.", None, keeperNumber)
	elif words[3] == "never":
		user.tip_frequency_days = 0
		user.save()
		sms_util.sendMsg(user, "Ok, I'll stop sending you tips.", None, keeperNumber)
	else:
		sms_util.sendMsg(user, "Sorry, I didn't get that. You can type 'send me tips weekly/monthly/never' to change how often I send you tips.", None, keeperNumber)


def help(user, msg, keeperNumber):
	sms_util.sendMsg(user, 'There are a few things I can help you with.', None, keeperNumber)
	time.sleep(1)
	sms_util.sendMsg(user, "I can remember anything you send me with a hashtag. Like '#cocktails old fashioned, mojito, margarita ", None, keeperNumber)
	time.sleep(1)
	sms_util.sendMsg(user, "I can set reminders for you. Like 'Remind me to call Mom tonight'", None, keeperNumber)
	time.sleep(1)
	sms_util.sendMsg(user, "I can also keep a shared list with your friends. Like 'Avengers #movies @beth' to share a movie with Beth.", None, keeperNumber)


def tellMeMore(user, msg, keeperNumber):
	sms_util.sendMsg(user, keeper_constants.TELL_ME_MORE, None, keeperNumber)

def setName(user, msg, keeperNumber):
	name = msg_util.nameInSetName(msg)
	if name and name != "":
		user.name = name
		user.save()
		sms_util.sendMsg(user, "Great, I'll call you %s from now on." % name, None, keeperNumber)
	else:
		sms_util.sendMsg(user, "Sorry, I didn't catch that, try saying something like 'My name is Keeper'" % name, None, keeperNumber)

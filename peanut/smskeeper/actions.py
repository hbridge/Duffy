import humanize

from smskeeper import sms_util, msg_util, helper_util, image_util
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
			if len(entries) == 1:
				sms_util.sendMsg(contact.target, "Ding ding! %s shared \"%s %s\" with you." % (user.nameOrPhone(), entry.text, entry.label), None, keeperNumber)
			else:
				sms_util.sendMsg(contact.target, "Ding ding! %s shared %d items under %s with you." % (user.nameOrPhone(), len(entries), entry.label), None, keeperNumber)
	return sharedHandles, notFoundHandles

def add(user, msg, requestDict, keeperNumber, sendResponse):
	text, label, media, handles = msg_util.getMessagePiecesWithMedia(msg, requestDict)

	# TODO use a separate process but probably this is not the right place to do it.
	if len(media) > 0:
		media = image_util.moveMediaToS3(media)

	createdEntries = list()

	# Text comes back without label but still has commas. Split on those here
	for entryText in text.split(','):
		entryText = entryText.strip()
		if len(entryText) > 0:
			entry = Entry.createEntry(user, keeperNumber, label, entryText)
			createdEntries.append(entry)

	for entryMediaUrl in media:
		entry = Entry.createEntry(user, keeperNumber, label, text=None, img_url=entryMediaUrl)
		createdEntries.append(entry)

	sharedHandles = list()
	notFoundHandles = list()
	shareString = ""
	if len(handles) > 0:
		sharedHandles, notFoundHandles = shareEntries(user, createdEntries, handles, keeperNumber)
	if len(sharedHandles) > 0:
		shareString = "  I also shared that with %s" % ", ".join(sharedHandles)

	if sendResponse:
		if label == keeper_constants.UNASSIGNED_LABEL:
			sms_util.sendMsg(user, "Filing that under " + keeper_constants.UNASSIGNED_LABEL + shareString, None, keeperNumber)
		else:
			sms_util.sendMsg(user, "Got it." + shareString, None, keeperNumber)

	return createdEntries, notFoundHandles


def fetch(user, msg, keeperNumber):
	# This is a label fetch.  See if a note with that label exists then return
	label = msg
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

	if contact is not None:
		contact.target = target_user
	else:
		contact = Contact.objects.create(user=user, handle=handle, target=target_user)
	contact.save()

	return oldUser

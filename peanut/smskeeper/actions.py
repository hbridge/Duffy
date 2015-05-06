import time
import random
import datetime
import pytz

from smskeeper import sms_util, msg_util, helper_util, image_util
from smskeeper import keeper_constants

from smskeeper.models import Entry, Contact


def shareEntries(user, entries, handles, keeperNumber):
	sharedHandles = list()
	notFoundHandles = list()
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

	#TODO use a separate process but probably this is not the right place to do it.
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

		if len(notFoundHandles) > 0:
			sms_util.sendMsg(user, "I don't know %s. Send @[name] [phone number] to introduce us." % ", ".join(notFoundHandles), None, keeperNumber)

	return entry


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
				try:
					contact = Contact.objects.get(user=user, target=otherUser)
					otherUserHandles.append(contact.handle)
				except Contact.DoesNotExist:
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


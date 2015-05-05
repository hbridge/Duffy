import json
from django.core.serializers.json import DjangoJSONEncoder
from multiprocessing import Process
import time
import random
import math
import pytz
import datetime
from datetime import date, timedelta
import humanize
import os, sys, re
import requests

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.dispatch import receiver
from django.db.models.signals import post_save

from django.shortcuts import render

from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt

from smskeeper.forms import UserIdForm, SmsContentForm, PhoneNumberForm, SendSMSForm
from smskeeper.models import User, Note, NoteEntry, Message, MessageMedia
from smskeeper import sms_util, image_util
from smskeeper import async

from common import api_util, natty_util
from peanut.settings import constants
from django.conf import settings


'''
Message constants
'''
UNASSIGNED_LABEL = '#unassigned'
REMIND_LABEL = "#reminders"


def sendNoResponse():
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response></Response>"
	print "Sending blank response"
	return HttpResponse(content, content_type="text/xml")

def sendNotFoundMessage(user, label, keeperNumber):
	sms_util.sendMsg(user, "Sorry, I don't have anything for %s" % label, None, keeperNumber)


def isNicety(msg):
	return msg.strip().lower() in ["hi", "hello", "thanks", "thank you"]
def isLabel(msg):
	stripedMsg = msg.strip()
	return (' ' in stripedMsg) == False and stripedMsg.startswith("#")

def isClearLabel(msg):
	stripedMsg = msg.strip()
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'clear') or (isLabel(tokens[1]) and tokens[0].lower()=='clear'))

def isPickFromLabel(msg):
	stripedMsg = msg.strip()
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'pick') or (isLabel(tokens[1]) and tokens[0].lower()=='pick'))

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

def isListsCommand(msg):
	return msg.strip().lower() == 'show lists' or msg.strip().lower() == 'show all'

def isHelpCommand(msg):
	return msg.strip().lower() == 'huh?'

def isPrintHashtagsCommand(msg):
	cleaned = msg.strip().lower()
	return  cleaned == '#hashtag' or cleaned == '#hashtags'

def isSendContactCommand(msg):
	return msg.strip().lower() == 'vcard'

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

# Returns back (textWithoutLabel, label, listOfUrls)
# Text could have comma's in it, that is dealt with later
def getData(msg, numMedia, requestDict):
	# process text
	nonLabels = list()
	label = None
	for word in msg.split(' '):
		if isLabel(word):
			label = word
		else:
			nonLabels.append(word)

	# process media
	mediaUrlList = list()

	for n in range(numMedia):
		param = 'MediaUrl' + str(n)
		mediaUrlList.append(requestDict[param])
		#TODO need to store mediacontenttype as well.

	#TODO use a separate process but probably this is not the right place to do it.
	if numMedia > 0:
		mediaUrlList = image_util.moveMediaToS3(mediaUrlList)
	return (' '.join(nonLabels), label, mediaUrlList)



def htmlForNote(note):
	html = "%s:\n"%(note.label)
	entries = NoteEntry.objects.filter(note=note).order_by("added")
	if len(entries) == 0:
		html += "(empty)<br><br>"
		return html

	count = 1
	html += "<ol>\n"
	for entry in entries:
		if not entry.img_url:
			html += "<li>%s</li>"%(entry.text)
			count += 1
		else:
			html += "<img src=\"%s\" />"%(entry.img_url)
	html+= "</ol>"

	return html

def sendContactCard(user, keeperNumber):
		cardURL = "https://s3.amazonaws.com/smskeeper/Keeper.vcf"
		sms_util.sendMsg(user, '', cardURL, keeperNumber)

def dealWithNicety(user, msg, keeperNumber):
	cleaned = msg.strip().lower()
	if "thank" in cleaned:
		sms_util.sendMsg(user, "You're welcome.", None, keeperNumber)
	if "hello" in cleaned or "hi" in cleaned:
		sms_util.sendMsg(user, "Hi there.", None, keeperNumber)

def dealWithAddMessage(user, msg, numMedia, keeperNumber, requestDict, sendResponse):
	text, label, media = getData(msg, numMedia, requestDict)
	note, created = Note.objects.get_or_create(user=user, label=label)

	# Text comes back without label but still has commas. Split on those here
	for entryText in text.split(','):
		entryText = entryText.strip()
		if len(entryText) > 0:
			noteEntry = NoteEntry.objects.create(note=note, text=entryText)

	for entryMediaUrl in media:
		noteEntry = NoteEntry.objects.create(note=note, img_url=entryMediaUrl)

	if sendResponse:
		if label == UNASSIGNED_LABEL:
			sms_util.sendMsg(user, "Filing that under " + UNASSIGNED_LABEL, None, keeperNumber)
		else:
			sms_util.sendMsg(user, "Got it", None, keeperNumber)

	return noteEntry

def dealWithRemindMessage(user, msg, keeperNumber, requestDict):
	text, label, media = getData(msg, 0, requestDict)
	startDate, newQuery, usedText = natty_util.getNattyInfo(text, user.timezone)

	# See if the time that comes back is within a few seconds.
	# If this happens, then we didn't get a time from the user
	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	if startDate == None or abs((now - startDate).total_seconds()) < 10:
		sms_util.sendMsg(user, "At what time?", None, keeperNumber)
		return
	else:
		doRemindMessage(user, startDate, newQuery, keeperNumber, requestDict)

def dealWithRemindMessageFollowup(user, msg, keeperNumber, requestDict):
	# Assuming this is the remind msg
	prevMessage = getPreviousMessage(user)
	text, label, media = getData(prevMessage.getBody(), prevMessage.NumMedia(), json.loads(prevMessage.msg_json))

	# First get the used Text from the last message
	startDate, newQuery, usedText = natty_util.getNattyInfo(text, user.timezone)

	# Now append on the new 'time' to that message, then pass to Natty
	if not usedText:
		usedText = ""
	newMsg = usedText + " " + msg

	# We want to ignore the newQuery here since we're only sending in time related stuff
	startDate, ignore, usedText = natty_util.getNattyInfo(newMsg, user.timezone)

	if not startDate:
		startDate = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)

	doRemindMessage(user, startDate, newQuery, keeperNumber, requestDict)


def doRemindMessage(user, startDate, query, keeperNumber, requestDict):
	# Need to do this so the add message correctly adds the label
	msgWithLabel = query + " " + REMIND_LABEL
	noteEntry = dealWithAddMessage(user, msgWithLabel, 0, keeperNumber, requestDict, False)

	# Hack where we add 5 seconds to the time so we support queries like "in 2 hours"
	# Without this, it'll return back "in 1 hour" because some time has passed and it rounds down
	# Have to pass in cleanDate since humanize doesn't use utcnow
	startDate = startDate.replace(tzinfo=None)
	userMsg = humanize.naturaltime(startDate + datetime.timedelta(seconds=5))

	noteEntry.remind_timestamp = startDate
	noteEntry.keeper_number = keeperNumber
	noteEntry.save()

	async.processReminder.apply_async([noteEntry.id], eta=startDate)

	sms_util.sendMsg(user, "Got it. Will remind you to %s %s" % (query, userMsg), None, keeperNumber)

def getPreviousMessage(user):
	# Normally would sort by added but unit tests barf since they get added at same time
	# Here, sorting by id should accomplish the same goal
	msgs = Message.objects.filter(user=user, incoming=True).order_by("-id")[:2]

	if len(msgs) == 2:
		return msgs[1]
	else:
		return None

def getInferredLabel(user):
	incoming_messages = Message.objects.filter(user=user, incoming=True).order_by("-added")
	if len(incoming_messages) < 2:
		return None

	for i in range(1, len(incoming_messages)):
		msg_body = incoming_messages[i].getBody()
		print "message -%d: %s" % (i, msg_body)
		if isLabel(msg_body):
			return msg_body
		elif isDeleteCommand(msg_body):
			continue
		else:
			return None

	return None

def dealWithDelete(user, msg, keeperNumber):
	words = msg.split(" ")
	requested_index = int(words[1])
	item_index = requested_index - 1
	label = None
	if hasLabel(msg):
		text, label, media = getData(msg, 0, None)
	else:
		label = getInferredLabel(user)

	if label:
		try:
			note = Note.objects.get(user=user, label=label)
			entries = NoteEntry.objects.filter(note=note, hidden=False).order_by("added")
			if item_index < 0 or item_index >= len(entries):
				sms_util.sendMsg(user, 'There is no item %d in %s' % (requested_index, label), None, keeperNumber)
				return
			entry = entries[item_index]
			entry.hidden = True
			entry.save()
			if entry.text:
				retMsg = entry.text
			else:
				retMsg = "item " + str(item_index+1)
			sms_util.sendMsg(user, 'Ok, I deleted "%s"' % (retMsg), None, keeperNumber)

			dealWithFetchMessage(user, label, 0, keeperNumber, None)
		except Note.DoesNotExist:
			sendNotFoundMessage(user, label, keeperNumber)
			return
	else:
		sms_util.sendMsg(user, 'Sorry, I\'m not sure which hashtag you\'re referring to. Try "delete [number] [hashtag]"', None, keeperNumber)

def dealWithFetchMessage(user, msg, numMedia, keeperNumber, requestDict):
	# This is a label fetch.  See if a note with that label exists then return
	label = msg
	try:
		# We support many different remind commands, but every one actually does REMIND_LABEL
		if isRemindCommand(label):
			label = REMIND_LABEL
		note = Note.objects.get(user=user, label=label)
		clearMsg = "\n\nSend 'clear %s' to clear or 'delete [number]' to delete an item."%(note.label)
		entries = NoteEntry.objects.filter(note=note, hidden=False).order_by("added")
		mediaUrls = list()

		if len(entries) == 0:
			sendNotFoundMessage(note.user, note.label, keeperNumber)
			return

		currentMsg = "%s:" % note.label

		count = 1
		for entry in entries:
			if entry.img_url:
				mediaUrls.append(entry.img_url)
			else:
				newStr = str(count) + ". " + entry.text

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

			sms_util.sendMsg(note.user, currentMsg + clearMsg, None, keeperNumber)
			sms_util.sendMsg(note.user, '', gridImageUrl, keeperNumber)
		else:
			sms_util.sendMsg(note.user, currentMsg + clearMsg, None, keeperNumber)
	except Note.DoesNotExist:
		sendNotFoundMessage(user, label, keeperNumber)


def dealWithPrintHashtags(user, keeperNumber):
	#print out all of the active hashtags for the account
	listText = ""
	try:
		for note in Note.objects.filter(user=user):
			entries = NoteEntry.objects.filter(note=note)
			if len(entries) > 0:
				listText += "%s (%d)\n" % (note.label, len(entries))
		sms_util.sendMsg(user, listText, None, keeperNumber)
	except Note.DoesNotExist:
		sms_util.sendMsg(user, "You don't have anything tagged. Yet.", None, keeperNumber)

def pickItemFromNote(note, keeperNumber):
	entries = NoteEntry.objects.filter(note=note, hidden=False).order_by("added")
	if len(entries) == 0:
		sendNotFoundMessage(user, label, keeperNumber)
		return

	entry = random.choice(entries)
	if entry.img_url:
		sms_util.sendMsg(note.user, "My pick for %s:"%note.label, None, keeperNumber)
		sms_util.sendMsg(note.user, entry.text, entry.img_url, keeperNumber)
	else:
		sms_util.sendMsg(note.user, "My pick for %s: %s"%(note.label, entry.text), None, keeperNumber)

def getFirstNote(user):
	notes = Note.objects.filter(user=user)
	if len(notes) > 0:
		return notes[0]
	else:
		return None

def dealWithNonActivatedUser(user, firstTime, keeperNumber):
	if firstTime:
		sms_util.sendMsg(user, "Hi. I'm Keeper.", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "I can help you remember things. But, I'm not quite ready for you yet.", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "Stay tuned. I'll be in touch soon.", None, keeperNumber)
	else:
		sms_util.sendMsg(user, "Oh hi. You're back!", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "I still need more time.", None, keeperNumber)

def dealWithActivation(user, msg, keeperNumber):
	text, label, media = getData(msg, 0, {})

	try:
		userToActivate = User.objects.get(phone_number=text)
		userToActivate.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		userToActivate.save()
		sms_util.sendMsg(user, "Done. %s is now activated" % text, None, keeperNumber)

		sms_util.sendMsg(userToActivate, "Hi, I'm ready now! As a reminder, I'm Keeper and I can keep track of your lists, notes, photos, etc.", None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(userToActivate, "Before I explain a bit more, what's your name?", None, keeperNumber)
	except User.DoesNotExist:
		sms_util.sendMsg(user, "Sorry, couldn't find a user with phone number %s" % text, None, keeperNumber)

def dealWithTutorial(user, msg, numMedia, keeperNumber, requestDict):
	if user.tutorial_step == 0:
		user.name = msg
		user.save()
		sms_util.sendMsg(user, "Great, nice to meet you %s" % user.name, None, keeperNumber)
		time.sleep(1)
		sms_util.sendMsg(user, "Let's try creating a list. Send an item you want to buy and add a hashtag. Like 'bread #grocery'", None, keeperNumber)
		user.tutorial_step = user.tutorial_step + 1
	elif user.tutorial_step == 1:
		if not hasLabel(msg):
			# They didn't send in something with a label.
			sms_util.sendMsg(user, "Actually, let's create a list first. Try 'bread #grocery'.", None, keeperNumber)
		else:
			# They sent in something with a label, have them add to it
			dealWithAddMessage(user, msg, numMedia, keeperNumber, requestDict, False)
			sms_util.sendMsg(user, "Now let's add another item to your list. Don't forget to add the same hashtag '%s'" % getLabel(msg), None, keeperNumber)
			user.tutorial_step = user.tutorial_step + 1
	elif user.tutorial_step == 2:
		# They should be sending in a second add command to an existing label
		if not hasLabel(msg) or isLabel(msg):
			existingLabel = getFirstNote(user).label
			if not existingLabel:
				sms_util.sendMsg(user, "I'm borked, well done", None, keeperNumber)
				return
			sms_util.sendMsg(user, "Actually, let's add to the first list. Try 'foobar %s'." % existingLabel, None, keeperNumber)
		else:
			dealWithAddMessage(user, msg, numMedia, keeperNumber, requestDict, False)
			sms_util.sendMsg(user, "You can add items to this list anytime (including photos). To see your list, send just the hashtag '%s' to me. Give it a shot." % getLabel(msg), None, keeperNumber)
			user.tutorial_step = user.tutorial_step + 1
	elif user.tutorial_step == 3:
		# The should be sending in just a label
		existingLabel = getFirstNote(user).label
		if not existingLabel:
			sms_util.sendMsg(user, "I'm borked, well done", None, keeperNumber)
			return

		if not isLabel(msg):
			sms_util.sendMsg(user, "Actually, let's view your list. Try '%s'." % existingLabel, None, keeperNumber)
			return

		if not Note.objects.filter(user=user, label=msg).exists():
			sms_util.sendMsg(user, "Actually, let's view the list you already created. Try '%s'." % existingLabel, None, keeperNumber)
			return
		else:
			dealWithFetchMessage(user, msg, numMedia, keeperNumber, requestDict)
			sms_util.sendMsg(user, "That should get you started. Send 'huh?' anytime to get help.", None, keeperNumber)
			time.sleep(1)
			sms_util.sendMsg(user, "Btw, here's an easy way to add me to your contacts.", None, keeperNumber)
			sendContactCard(user, keeperNumber)
			user.completed_tutorial = True

	user.save()

"""
	Helper method for command line interface input.  Use by:
	python
	>> from smskeeper import views
	>> views.cliMsg("+16508158274", "blah #test")
"""
def cliMsg(phoneNumber, msg, mediaURL=None, mediaType=None):
	numMedia = 0
	jsonDict = {
		"Body": msg,
	}

	if mediaURL is not None:
		numMedia = 1
		jsonDict["MediaUrl0"] = mediaURL
		if mediaType is not None:
			jsonDict["MediaContentType0"] = mediaType
		jsonDict["NumMedia"] = 1

	processMessage(phoneNumber, msg, numMedia, jsonDict, "test")

"""
	Main logic for processing a message
	Pulled out so it can be called either from sms code or command line
"""
def processMessage(phoneNumber, msg, numMedia, requestDict, keeperNumber):
	try:
		user = User.objects.get(phone_number=phoneNumber)
	except User.DoesNotExist:
		user = User.objects.create(phone_number=phoneNumber)
		dealWithNonActivatedUser(user, True, keeperNumber)
		return
	finally:
		Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True)

	if user.activated == None:
		dealWithNonActivatedUser(user, False, keeperNumber)
	elif not user.completed_tutorial:
		dealWithTutorial(user, msg, numMedia, keeperNumber, requestDict)
	elif isActivateCommand(msg) and phoneNumber in constants.DEV_PHONE_NUMBERS:
		dealWithActivation(user, msg, keeperNumber)
	elif isPrintHashtagsCommand(msg):
		# this must come before the isLabel() hashtag fetch check or we will try to look for a #hashtags list
		dealWithPrintHashtags(user, keeperNumber)
	elif isLabel(msg) and numMedia == 0:
		if user.completed_tutorial:
			dealWithFetchMessage(user, msg, numMedia, keeperNumber, requestDict)
		else:
			time.sleep(1)
			dealWithTutorial(user, msg, numMedia, keeperNumber, requestDict)
	elif isClearLabel(msg) and numMedia == 0:
		try:
			label = getLabel(msg)
			note = Note.objects.get(user=user, label=label)
			note.delete()
			sms_util.sendMsg(user, "%s cleared"% (label), None, keeperNumber)
		except Note.DoesNotExist:
			sendNotFoundMessage(user, label, keeperNumber)
	elif isPickFromLabel(msg) and numMedia == 0:
		label = getLabel(msg)
		try:
			note = Note.objects.get(user=user, label=label)
			pickItemFromNote(note, keeperNumber)
		except Note.DoesNotExist:
			sendNotFoundMessage(user, label, keeperNumber)
	elif isHelpCommand(msg):
		sms_util.sendMsg(user, "You can create a list by adding #listname to any msg.\n You can retrieve all items in a list by typing just '#listname' in a message.", None, keeperNumber)
	elif isSendContactCommand(msg):
		sendContactCard(user, keeperNumber)
	elif isRemindCommand(msg):
		dealWithRemindMessage(user, msg, keeperNumber, requestDict)
	elif isDeleteCommand(msg):
		dealWithDelete(user, msg, keeperNumber)
	else: # treat this as an add command
		if user.completed_tutorial:
			# Hack until state machine.
			# See if the last message was a remind and if if this doesn't have a label
			prevMsg = getPreviousMessage(user)
			if prevMsg and isRemindCommand(prevMsg.getBody()) and not hasLabel(msg):
				dealWithRemindMessageFollowup(user, msg, keeperNumber, requestDict)
			elif not hasLabel(msg):
				if isNicety(msg):
					dealWithNicety(user, msg, keeperNumber)
					return
				# if the user didn't add a label, throw it in #unassigned
				msg += ' ' + UNASSIGNED_LABEL
				dealWithAddMessage(user, msg, numMedia, keeperNumber, requestDict, True)
			else:
				dealWithAddMessage(user, msg, numMedia, keeperNumber, requestDict, True)
		else:
			time.sleep(1)
			dealWithTutorial(user, msg, numMedia, keeperNumber, requestDict)

#
# Send a sms message to a user from a certain number
# If from_num isn't specified, then defaults to prod
#
# Example url:
# http://dev.duffyapp.com:8000/smskeeper/send_sms?user_id=23&msg=Test&from_num=%2B12488178301
#
def send_sms(request):
	form = SendSMSForm(api_util.getRequestData(request))
	response = dict()
	if (form.is_valid()):
		user = form.cleaned_data['user']
		msg = form.cleaned_data['msg']
		keeperNumber = form.cleaned_data['from_num']

		if not keeperNumber:
			keeperNumber = constants.TWILIO_SMSKEEPER_PHONE_NUM

		sms_util.sendMsg(user, msg, None, keeperNumber)

		response["result"] = True
		return HttpResponse(json.dumps(response), content_type="text/json", status=200)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


@csrf_exempt
def incoming_sms(request):
	form = SmsContentForm(api_util.getRequestData(request))

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['From'])
		keeperNumber = str(form.cleaned_data['To'])
		msg = form.cleaned_data['Body']
		numMedia = int(form.cleaned_data['NumMedia'])
		requestDict = api_util.getRequestData(request)

		processMessage(phoneNumber, msg, numMedia, requestDict, keeperNumber)
		return sendNoResponse()

	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)

def all_notes(request):
	form = PhoneNumberForm(api_util.getRequestData(request))

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['PhoneNumber'])
		try:
			user = User.objects.get(phone_number=phoneNumber)
			html = ""
			for note in Note.objects.filter(user=user):
				html += htmlForNote(note)
			return HttpResponse(html, content_type="text/html", status=200)
		except User.DoesNotExist:
			return sendResponse("Phone number not found")
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)

def history(request):
	form = UserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		context = {	'user_id': user.id }
		return render(request, 'thread_view.html', context)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)

def message_feed(request):
	form = UserIdForm(api_util.getRequestData(request))
	if (form.is_valid()):
		user = form.cleaned_data['user']

		messages = Message.objects.filter(user=user).order_by("added")
		messages_dicts = []

		for message in messages:
			message_dict = json.loads(message.msg_json)
			if len(message_dict.keys()) > 0:
				if not message_dict.get("From", None):
					message_dict["From"] = user.phone_number
				message_dict["added"] = message.added
				messages_dicts.append(message_dict)
				if message_dict.get("From") == user.phone_number:
					message_dict["incoming"] = True
		return HttpResponse(json.dumps({"messages" : messages_dicts}, cls=DjangoJSONEncoder), content_type="text/json", status=200)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


def dashboard_feed(request):
	users = User.objects.all().order_by("id");
	user_dicts = []
	for user in users:
		dict = {
			"id" : int(user.id),
			"phone_number" : user.phone_number,
			"name" : user.name,
			"activated" : user.activated,
			"created" : user.added,
			"tutorial_step" : user.tutorial_step,
			"completed_tutorial" : user.completed_tutorial
		}

		dict["message_stats"] = {}
		for direction in ["incoming", "outgoing"]:
			incoming = (direction == "incoming")
			messages = Message.objects.filter(user=user, incoming=incoming).order_by("-added")
			count = messages.count()
			last_message_date = None
			if count > 0:
				last_message_date = messages[0].added
			dict["message_stats"][direction] = {
				"count" : count,
				"last" : last_message_date,
			}
		dict["history"] = "history?user_id=" + str(user.id)

		user_dicts.append(dict)

	daily_stats = {}
	for days_ago in [1, 3, 7, 30]:
		date_filter = date.today() - timedelta(days=days_ago)
		daily_stats[days_ago] = {}
		for direction in ["incoming", "outgoing"]:
			incoming = (direction == "incoming")
			messages = Message.objects.filter(incoming=incoming, added__gt=date_filter)
			message_count = messages.count()
			user_count = messages.values('user').distinct().count()
			daily_stats[days_ago][direction] = {
				"messages" : message_count,
				"user_count" : user_count
			}

	responseJson = json.dumps({"users" : user_dicts, "daily_stats" : daily_stats}, cls=DjangoJSONEncoder)
	return HttpResponse(responseJson, content_type="text/json", status=200)

def dashboard(request):
	return render(request, 'dashboard.html', None)

@receiver(post_save, sender=Message)
def sendLiveFeed(sender, **kwargs):
	if settings.DEBUG == False:
		message = kwargs.get('instance')
		msgContent = json.loads(message.msg_json)

		url = 'https://hooks.slack.com/services/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'
		channel = "#livesmskeeperfeed"
		params = dict()
		text = msgContent['Body']

		if message.incoming:
			userName = message.user.name + ' (' + message.user.phone_number + ')'

			numMedia = int(msgContent['NumMedia'])

			if numMedia > 0:
				for n in range(numMedia):
					param = 'MediaUrl' + str(n)
					text += "\n<" + requestDict[param] + "|" + param + ">"
			params['icon_emoji'] = ':raising_hand:'

		else:
			userName = "Keeper" + " (to: " + message.user.name + ")"
			if msgContent['MediaUrls']:
				text += " <" + str(msgContent['MediaUrls']) + "|Attachment>"
			params['icon_emoji'] = ':rabbit:'


		params['username'] = userName
		params['text'] = text
		params['channel'] = channel

		resp = requests.post(url, data=json.dumps(params))

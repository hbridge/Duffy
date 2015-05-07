import json
from multiprocessing import Process
import time
import random
import math
import pytz
import datetime
from datetime import date, timedelta
import os, sys, re
import requests
import phonenumbers
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.shortcuts import render

from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.dispatch import receiver
from django.db.models.signals import post_save
from django.core.serializers.json import DjangoJSONEncoder

from smskeeper.forms import UserIdForm, SmsContentForm, PhoneNumberForm, SendSMSForm, ResendMsgForm

from smskeeper.models import User, Entry, Message, MessageMedia, Contact


from smskeeper import sms_util, image_util, msg_util, processing_util, helper_util
from smskeeper import async, actions, keeper_constants

from common import api_util
from peanut.settings import constants
from peanut import settings

logger = logging.getLogger(__name__)


def sendNoResponse():
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response></Response>"
	logger.info("Sending blank response")
	return HttpResponse(content, content_type="text/xml")

#  Returns back (textWithoutLabel, label, listOfUrls, listOfHandles)
# Text could have comma's in it, that is dealt with later
def getData(msg, numMedia, requestDict):
	# process text
	nonLabels = list()
	handleList = list()
	label = None
	for word in msg.split(' '):
		if msg_util.isLabel(word):
			label = word
		elif msg_util.isHandle(word):
			handleList.append(word)
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
	return (' '.join(nonLabels), label, mediaUrlList, handleList)



def htmlForUserLabel(user, label):
	html = "%s:\n"%(label)
	entries = Entry.fetchEntries(user, label)
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

def dealWithNicety(user, msg, keeperNumber):
	cleaned = msg.strip().lower()
	if "thank" in cleaned:
		sms_util.sendMsg(user, "You're welcome.", None, keeperNumber)
	if "hello" in cleaned or "hi" in cleaned:
		sms_util.sendMsg(user, "Hi there.", None, keeperNumber)

def dealWithYesNo(user, msg, keeperNumber):
	sms_util.sendMsg(user, u"\xF0\x9F\x98\xB3 I'm not smart enough to know what you mean yet.  Try 'huh?' if you're stuck.", None, keeperNumber)

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
		print "word, subwords: %s, %s" % (word, subwords)
		for subword in subwords:
			try:
				requested_indices.add(int(subword))
			except:
				pass
	print "requested indices: %s" % requested_indices
	item_indices = map(lambda x: x - 1, requested_indices)

	item_indices = sorted(item_indices, reverse=True)
	print item_indices

	label = None
	if msg_util.hasLabel(msg):
		text, label, media, handles = getData(msg, 0, None)
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
		sms_util.sendMsg(user, "My pick for %s:"%label, None, keeperNumber)
		sms_util.sendMsg(user, entry.text, entry.img_url, keeperNumber)
	else:
		sms_util.sendMsg(user, "My pick for %s: %s"%(label, entry.text), None, keeperNumber)

def dealWithActivation(user, msg, keeperNumber):
	text, label, media, handles = getData(msg, 0, {})

	try:
		userToActivate = User.objects.get(phone_number=text)
		userToActivate.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		userToActivate.save()
		sms_util.sendMsg(user, "Done. %s is now activated" % text, None, keeperNumber)

		sms_util.sendMsg(userToActivate, "Oh hello. Someone else entered your magic phrase. Welcome!", None, keeperNumber)
		time.sleep(1)
		helper_util.firstRunIntro(userToActivate, keeperNumber)
	except User.DoesNotExist:
		sms_util.sendMsg(user, "Sorry, couldn't find a user with phone number %s" % text, None, keeperNumber)


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

def dealWithCreateHandle(user, msg, keeperNumber):
	words = msg.strip().split(' ')
	handle = None
	for word in words:
		if msg_util.isHandle(word):
			handle = word
			break

	phoneNumbers = msg_util.extractPhoneNumbers(msg)
	phoneNumber = phoneNumbers[0]

	oldUser = createHandle(user, handle, phoneNumber)

	if oldUser is not None:
		if oldUser.phone_number == phoneNumber:
			sms_util.sendMsg(user, "%s is already set to %s" % (handle, phoneNumber), None, keeperNumber)
		else:
			sms_util.sendMsg(user, "%s is now set to %s (used to be %s)" % (handle, phoneNumber, oldUser.phone_number), None, keeperNumber)
	else:
		sms_util.sendMsg(user, "%s is now set to %s" % (handle, phoneNumber), None, keeperNumber)

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
	else:
		jsonDict["NumMedia"] = 0

	processMessage(phoneNumber, msg, numMedia, jsonDict, constants.SMSKEEPER_TEST_NUM)

"""
	Main logic for processing a message
	Pulled out so it can be called either from sms code or command line
"""
def processMessage(phoneNumber, msg, numMedia, requestDict, keeperNumber):
	try:
		user = User.objects.get(phone_number=phoneNumber)
	except User.DoesNotExist:
		try:
			user = User.objects.create(phone_number=phoneNumber)
		except Exception as e:
			logger.error("Got Exception in user creation: %s" % e)
	except Exception as e:
		logger.error("Got Exception in user creation: %s" % e)
	finally:
		Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True)


	if user.state != keeper_constants.STATE_NORMAL:
		processing_util.processMessage(user, msg, requestDict, keeperNumber)
	# STATE_REMIND
	elif msg_util.isRemindCommand(msg) and not msg_util.isClearCommand(msg) and not msg_util.isFetchCommand(msg):
		# TODO  Fix this state so the logic isn't so complex
		user.setState(keeper_constants.STATE_REMIND)
		processing_util.processMessage(user, msg, requestDict, keeperNumber)
	elif msg_util.isActivateCommand(msg) and phoneNumber in constants.DEV_PHONE_NUMBERS:
		dealWithActivation(user, msg, keeperNumber)
	# STATE_NORMAL
	elif msg_util.isPrintHashtagsCommand(msg):
		# this must come before the isLabel() hashtag fetch check or we will try to look for a #hashtags list
		dealWithPrintHashtags(user, keeperNumber)
	# STATE_NORMAL
	elif msg_util.isFetchCommand(msg) and numMedia == 0:
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
		sms_util.sendMsg(user, "You can create a list by adding #listname to any msg.\n You can retrieve all items in a list by typing just '#listname' in a message.", None, keeperNumber)
	# STATE_ADD
	elif msg_util.isCreateHandleCommand(msg):
		dealWithCreateHandle(user, msg, keeperNumber)

	# STATE_DELETE
	elif msg_util.isDeleteCommand(msg):
		dealWithDelete(user, msg, keeperNumber)
	else: # treat this as an add command
		# STATE_NORMAL
		# STATE_ADD
		if not msg_util.hasLabel(msg):
			if msg_util.isNicety(msg):
				dealWithNicety(user, msg, keeperNumber)
				return
			elif msg_util.isYesNo(msg):
				dealWithYesNo(user, msg, keeperNumber)
				return
			# if the user didn't add a label, throw it in #unassigned
			msg += ' ' + keeper_constants.UNASSIGNED_LABEL
			actions.add(user, msg, requestDict, keeperNumber, True)
		else:
			actions.add(user, msg, requestDict, keeperNumber, True)

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

#
# Send a sms message to a user from a certain number
# If from_num isn't specified, then defaults to prod
#
# Example url:
# http://dev.duffyapp.com:8000/smskeeper/send_sms?user_id=23&msg=Test&from_num=%2B12488178301
#
def resend_msg(request):
	form = ResendMsgForm(api_util.getRequestData(request))
	response = dict()
	if (form.is_valid()):
		msgId = form.cleaned_data['msg_id']
		keeperNumber = form.cleaned_data['from_num']

		message = Message.objects.get(id=msgId)
		data = json.loads(message.msg_json)

		sms_util.sendMsg(message.user, data["Body"], None, keeperNumber)

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
	form = UserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		try:
			html = ""
			for label in Entry.fetchAllLabels(user):
				html += htmlForUserLabel(user, label)
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
	message = kwargs.get('instance')
	msgContent = json.loads(message.msg_json)
	if ('To' in msgContent and msgContent['To'] in constants.KEEPER_PROD_PHONE_NUMBERS) or ('From' in msgContent and msgContent['From'] in constants.KEEPER_PROD_PHONE_NUMBERS):
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
			if message.user.name:
				name = message.user.name
			else:
				name = message.user.phone_number
			userName = "Keeper" + " (to: " + name + ")"
			if msgContent['MediaUrls']:
				text += " <" + str(msgContent['MediaUrls']) + "|Attachment>"
			params['icon_emoji'] = ':rabbit:'


		params['username'] = userName
		params['text'] = text
		params['channel'] = channel

		resp = requests.post(url, data=json.dumps(params))

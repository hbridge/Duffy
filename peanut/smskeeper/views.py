import json

from django.shortcuts import render

from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt

from smskeeper.forms import UserIdForm, SmsContentForm
from smskeeper.models import User, Note, NoteEntry, IncomingMessage

from strand import notifications_util
from common import api_util
from peanut.settings import constants

def sendResponse(msg):
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response><Sms>%s</Sms></Response>" % msg
	print "Sending response %s" % msg
	return HttpResponse(content, content_type="text/xml")

def sendMsg(user, msg):
	print "Sending %s" % msg
	notifications_util.sendSMSThroughTwilio(user.phone_number, msg, None, constants.TWILIO_SMSKEEPER_PHONE_NUM)

def sendNoResponse():
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response></Response>"
	print "Sending blank response"
	return HttpResponse(content, content_type="text/xml")

def sendImageEntry():
	pass

def isLabel(msg):
	stripedMsg = msg.strip()
	return (' ' in stripedMsg) == False and stripedMsg.startswith("#")

def isClearLabel(msg):
	stripedMsg = msg.strip()
	tokens = msg.split(' ')
	return len(tokens) == 2 and ((isLabel(tokens[0]) and tokens[1].lower() == 'clear') or (isLabel(tokens[1]) and tokens[0].lower()=='clear'))

def hasList(msg):
	for word in msg.split(' '):
		if isLabel(word):
			return True
	return False

def getLabel(msg):
	for word in msg.split(' '):
		if isLabel(word):
			return word
	return None

def getData(msg, numMedia, request):
	# process text
	nonLabels = list()
	label = None
	for word in msg.split(' '):
		if isLabel(word):
			label = word
		else:
			nonLabels.append(word)

	# process media
	media = list()
	# TODO 

	return (' '.join(nonLabels), label, media)

def sendBackNote(note):
	clearMsg = "Send '%s clear' to clear this list."%(note.label)
	entries = NoteEntry.objects.filter(note=note).order_by("added")
	hasImages = False
	if len(entries) == 0:
		return False

	currentMsg = "%s:" % note.label
	responseSent = False

	for entry in entries:
		if not entry.img_urls_json:
			currentMsg = currentMsg + "\n" + entry.text
		else:
			hasImages = True

	if hasImages:
		sendMsg(note.user, currentMsg)

		for entry in entries:
			if entry.img_urls_json:
				sendImageEntry(entry)
		return sendNoResponse()
	else:
		return sendResponse(currentMsg)

@csrf_exempt
def incoming_sms(request):
	form = SmsContentForm(api_util.getRequestData(request))

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['From'])
		msg = str(form.cleaned_data['Body'])
		numMedia = int(form.cleaned_data['NumMedia'])

		try:
			user = User.objects.get(phone_number=phoneNumber)
		except User.DoesNotExist:
			user = User.objects.create(phone_number=phoneNumber)

			return sendResponse("Hi. I'm Keeper. I can keep track of your lists, notes, photos, etc.\n\nLet's try creating your grocery list. Type an item you want to buy and add '#grocery' at the end.")
		finally:
			IncomingMessage.objects.create(user=user, msg_json=json.dumps(msg))

			
		if numMedia == 0 and isLabel(msg):
			# This is a label fetch.  See if a note with that label exists then return
			label = msg
			try:
				note = Note.objects.get(user=user, label=label)
				response = sendBackNote(note)
				if response:
					return response
				else:
					return sendResponse("Sorry, I didn't find anything for %s" % label)

			except Note.DoesNotExist:
				return sendResponse("Sorry, I didn't find anything for %s" % label)
		elif numMedia == 0 and isClearLabel(msg):
			try:
				label = getLabel(msg)
				note = Note.objects.get(user=user, label=label)
				note.delete()
				return sendResponse("%s cleared"% (label))
			except Note.DoesNotExist:
				return sendResponse("Sorry, I don't have anything for %s" % label)
		elif hasList(msg):
			text, label, media = getData(msg, numMedia, request)
			note, created = Note.objects.get_or_create(user=user, label=label)

			entry = NoteEntry(note=note)
			if text:
				entry.text = text
			if media:
				entry.img_urls_json = json.dumps(media)
			entry.save()
			return sendResponse("Got it")
		else:
			return sendResponse("Oops I need a label for that message. ex: #grocery, #tobuy, #toread")
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)

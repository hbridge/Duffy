from django.shortcuts import render

from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt

from smskeeper.forms import UserIdForm, SmsContentForm
from smskeeper.models import User, Note

from common import api_util

def sendResponse(msg):
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response><Sms>%s</Sms></Response>" % msg
	print "Sending response %s" % msg
	return HttpResponse(content, content_type="text/xml")

def isLabel(msg):
	stripedMsg = msg.strip()
	return (' ' in stripedMsg) == False and stripedMsg.startswith("#")

def hasList(msg):
	for word in msg.split(' '):
		if isLabel(word):
			return True
	return False

def getData(msg):
	nonLabels = list()
	label = None
	for word in msg.split(' '):
		if isLabel(word):
			label = word
		else:
			nonLabels.append(word)
	return (' '.join(nonLabels), label)

@csrf_exempt
def incoming_sms(request):
	form = SmsContentForm(api_util.getRequestData(request))

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['From'])
		msg = str(form.cleaned_data['Body'])

		try:
			user = User.objects.get(phone_number=phoneNumber)
		except User.DoesNotExist:
			user = User.objects.create(phone_number=phoneNumber)
			return sendResponse("Hi, nice to meet you.  I'm SMS Keeper.  Simply send me a message with a #listname and I'll remember it for you")

		if isLabel(msg):
			try:
				label = msg
				note = Note.objects.get(user=user, label=label)
				return sendResponse("%s:\n%s" % (label, note.text))
			except Note.DoesNotExist:
				return sendResponse("Sorry, I don't have anything for %s" % label)
		elif hasList(msg):
			content, label = getData(msg)
			note, created = Note.objects.get_or_create(user=user, label=label)
			if note.text == None:
				note.text = ""
			note.text = note.text + content + '\n'
			note.save()
			return sendResponse("Got it")
		else:
			return sendResponse("What list do you want to add that to? ex: #grocery, #tobuy, #toread")
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)

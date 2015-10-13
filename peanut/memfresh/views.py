import os
import logging
import json
import time
import datetime

from django.contrib.auth.decorators import login_required
from django.core.urlresolvers import reverse
from django.http import HttpResponse
from django.http import HttpResponseBadRequest
from django.http import HttpResponseRedirect
from django.shortcuts import render_to_response
from django.views.decorators.csrf import csrf_exempt

from django.conf import settings

from django_inbound_email.signals import email_received

from oauth2client.django_orm import Storage

from memfresh.models import User, FollowUp, ContactEntry, CredentialsModel
from memfresh.forms import UserIdForm, AuthForm, SmsContentForm, TelegramForm
from memfresh import utils
from peanut.settings import constants

from common import api_util

logger = logging.getLogger(__name__)

AUTH_LINK = "http://dev.duffyapp.com/memfresh/do_auth"

def getAuthLink(user):
	return "%s?user_id=%s" % (AUTH_LINK, user.id)

def on_email_received(sender, **kwargs):
	"""Handle inbound emails."""
	email = kwargs.pop('email')
	request = kwargs.pop('request')

	# your code goes here - save the email, respond to it, etc.
	logger.debug(
		"New email received from %s: %s -- %s",
		email.from_email,
		email.subject,
		email.body
	)
	print("New email received from %s: %s -- %s" % (email.from_email, email.subject, email.body))

# pass dispatch_uid to prevent duplicates:
# https://docs.djangoproject.com/en/dev/topics/signals/
email_received.connect(on_email_received, dispatch_uid="something_unique")

def send_response(msg):
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response><Sms>%s</Sms></Response>" % msg
	return HttpResponse(content, content_type="text/xml")

@csrf_exempt
def incoming_sms(request):
	form = SmsContentForm(api_util.getRequestData(request))

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['From'])
		msg = str(form.cleaned_data['Body'])

		try:
			user = User.objects.get(phone_number=phoneNumber)
		except User.DoesNotExist:
			user = None

		if not user:
			# No User, create and do first message back
			user = User.objects.create(phone_number=phoneNumber)
			return send_response("Hi, it seems we haven't met before. Please go to %s so I can get to know you." % getAuthLink(user))
		elif not CredentialsModel.objects.filter(user=user).exists():
			return send_response("Hi, it seems we need to auth. Please go to %s" % getAuthLink(user))
		else:
			calService = utils.getService(user, "calendar")
			if not calService:
				return send_response("Hi, it seems we need to auth. Please go to %s" % getAuthLink(user))

			followUps = utils.getLastEventFollowUpsForUser(user)

			for followUp in followUps:
				if followUp.text == None:
					followUp.text = ""
				followUp.text = followUp.text + msg + '\n'
				followUp.save()
			return send_response("Got it")
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


@csrf_exempt
def incoming_telegram(request):
	form = TelegramForm(api_util.getRequestData(request))

	if form.is_valid():
		updateId = form.cleaned_data['update_id']
		message = json.loads(form.cleaned_data['message'])
		logger.info("Received telegram update %d: %s", updateId, message)
	else:
		logger.info("Received malformed telegram message: %s", request)

def do_auth(request):
	response = dict({'result': True})
	form = UserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = User.objects.get(id=form.cleaned_data['user_id'])
		peopleService = utils.getService(user, "plus")
		calService = utils.getService(user, "calendar")

		if not peopleService or not calService:
			return utils.getUserRedirect(user)

		if not user.email or not user.name:
			people_resource = peopleService.people()
			people_document = people_resource.get(userId='me').execute()
			user.name = people_document["displayName"]
			user.email = people_document["emails"][0]["value"]
			user.save()

		event = utils.getMostCompletedRecentEvent(calService, datetime.timedelta(hours=4))
		utils.askForFollowUpForEvent(user, event)

		firstName = user.name.split(' ')[0]
		return HttpResponse("<h1>Thanks %s, you're good!  You can go back to the messages app</h1>" % firstName)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response), content_type="application/json")



def get_followup(request):
	response = dict({'result': True})
	form = UserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = User.objects.get(id=form.cleaned_data['user_id'])
		calService = utils.getService(user, "calendar")
		peopleService = utils.getService(user, "plus")

		if not calService:
			return utils.getUserRedirect(user)

		event = utils.getMostCompletedRecentEvent(calService, datetime.timedelta(hours=4))

		if event:
			print event
			followUpIds = utils.getEventIdsWithFollowUps(user)
			if event["id"] not in followUpIds:
				utils.askForFollowUpForEvent(user, event)
		return HttpResponse(json.dumps(response), content_type="application/json")
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response), content_type="application/json")

def auth_return(request):
	response = dict({'result': True})
	form = AuthForm(api_util.getRequestData(request))

	if (form.is_valid()):
		credential = utils.FLOW.step2_exchange(request.REQUEST)
		user = User.objects.get(id=form.cleaned_data['state'])
		storage = Storage(CredentialsModel, 'user', user, 'credential')
		storage.put(credential)

		return HttpResponseRedirect(getAuthLink(user))

	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)


import json
from datetime import date, timedelta
import os
import sys
import phonenumbers
import logging
import string

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut.settings import constants

from common import api_util, slack_logger
from common.models import ContactEntry
from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.core.serializers.json import DjangoJSONEncoder
from django.http import HttpResponse
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from smskeeper import sms_util, processing_util, keeper_constants, user_util
from smskeeper.forms import UserIdForm, SmsContentForm, SendSMSForm, ResendMsgForm, WebsiteRegistrationForm
from smskeeper.models import User, Entry, Message

from smskeeper.states import not_activated
from smskeeper import analytics

logger = logging.getLogger(__name__)


def jsonp(f):
	"""Wrap a json response in a callback, and set the mimetype (Content-Type) header accordingly
	(will wrap in text/javascript if there is a callback). If the "callback" or "jsonp" paramters
	are provided, will wrap the json output in callback({thejson})

	Usage:

	@jsonp
	def my_json_view(request):
		d = { 'key': 'value' }
		return HTTPResponse(json.dumps(d), content_type='application/json')

	"""
	from functools import wraps

	@wraps(f)
	def jsonp_wrapper(request, *args, **kwargs):
		resp = f(request, *args, **kwargs)
		if resp.status_code != 200:
			return resp
		if 'callback' in request.GET:
			callback = request.GET['callback']
			resp['Content-Type'] = 'text/javascript; charset=utf-8'
			resp.content = "%s(%s)" % (callback, resp.content)
			return resp
		elif 'jsonp' in request.GET:
			callback = request.GET['jsonp']
			resp['Content-Type'] = 'text/javascript; charset=utf-8'
			resp.content = "%s(%s)" % (callback, resp.content)
			return resp
		else:
			return resp

	return jsonp_wrapper


def sendNoResponse():
	content = '<?xml version="1.0" encoding="UTF-8"?>\n'
	content += "<Response></Response>"
	return HttpResponse(content, content_type="text/xml")


def htmlForUserLabel(user, label):
	html = "%s:\n" % (label)
	entries = Entry.fetchEntries(user, label)
	if len(entries) == 0:
		html += "(empty)<br><br>"
		return html

	count = 1
	html += "<ol>\n"
	for entry in entries:
		if not entry.img_url:
			html += "<li>%s</li>" % (entry.text)
			count += 1
		else:
			html += "<img src=\"%s\" />" % (entry.img_url)
	html += "</ol>"

	return html


@csrf_exempt
def incoming_sms(request):
	form = SmsContentForm(api_util.getRequestData(request))

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['From'])
		keeperNumber = str(form.cleaned_data['To'])
		msg = form.cleaned_data['Body']
		requestDict = api_util.getRequestData(request)

		processing_util.processMessage(phoneNumber, msg, requestDict, keeperNumber)
		return sendNoResponse()

	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


@login_required(login_url='/admin/login/')
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
			return HttpResponse(json.dumps({'phone_number': "Not Found"}), content_type="text/json", status=400)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


@login_required(login_url='/admin/login/')
def history(request):
	form = UserIdForm(api_util.getRequestData(request))
	if (form.is_valid()):
		user = form.cleaned_data['user']
		context = dict()

		phoneNumToContactDict = getNameFromContactsDB([user.phone_number])

		context["user_data"] = json.dumps(getUserDataDict(user, phoneNumToContactDict), cls=DjangoJSONEncoder)
		context["development"] = settings.DEBUG
		if form.cleaned_data['development']:
			context["development"] = form.cleaned_data['development']

		return render(request, 'history.html', context)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


def getMessagesForUser(user):
	messages = Message.objects.filter(user=user).order_by("added")
	messages_dicts = []

	for message in messages:
		message_dict = json.loads(message.msg_json)
		if len(message_dict.keys()) > 0:
			message_dict["id"] = message.id
			if not message_dict.get("From", None):
				message_dict["From"] = user.phone_number
			message_dict["added"] = message.added
			messages_dicts.append(message_dict)
			if message_dict.get("From") == user.phone_number:
				message_dict["incoming"] = True

	return messages_dicts


def getResponseForUser(user):
	response = dict()
	messages_dicts = getMessagesForUser(user)
	response['messages'] = messages_dicts
	response['paused'] = user.isPaused()

	return response


# External
@login_required(login_url='/admin/login/')
def message_feed(request):
	form = UserIdForm(api_util.getRequestData(request))
	if (form.is_valid()):
		user = form.cleaned_data['user']

		return HttpResponse(json.dumps(getResponseForUser(user), cls=DjangoJSONEncoder), content_type="text/json", status=200)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


#
# Send a sms message to a user from a certain number
# If from_num isn't specified, then defaults to prod
#
# Example url:
# http://dev.duffyapp.com:8000/smskeeper/send_sms?user_id=23&msg=Test&from_num=%2B12488178301
#
@csrf_exempt
def send_sms(request):
	form = SendSMSForm(api_util.getRequestData(request))
	if (form.is_valid()):
		user = form.cleaned_data['user']
		msg = form.cleaned_data['msg']
		keeperNumber = form.cleaned_data['from_num']
		direction = form.cleaned_data['direction']

		if not keeperNumber:
			keeperNumber = settings.KEEPER_NUMBER

		if direction == "ToUser":
			sms_util.sendMsg(user, msg, None, keeperNumber, manual=True)
		else:
			requestDict = dict()
			requestDict["Body"] = msg
			requestDict["To"] = keeperNumber
			requestDict["From"] = user.phone_number
			requestDict["Manual"] = True
			processing_util.processMessage(user.phone_number, msg, requestDict, keeperNumber)

		return HttpResponse(json.dumps(getResponseForUser(user), cls=DjangoJSONEncoder), content_type="text/json", status=200)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


@csrf_exempt
def toggle_paused(request):
	form = UserIdForm(api_util.getRequestData(request))
	if (form.is_valid()):
		user = form.cleaned_data['user']

		if user.isPaused():
			user.paused = False
			msg = "User %s just got unpaused" % (user.id)
			slack_logger.postManualAlert(user, msg, constants.KEEPER_PROD_PHONE_NUMBERS[0], keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)
		else:
			user.paused = True
		user.save()

		return HttpResponse(json.dumps(getResponseForUser(user), cls=DjangoJSONEncoder), content_type="text/json", status=200)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


#
# Send a sms message to a user from a certain number
# If from_num isn't specified, then defaults to prod
#
# Example url:
# http://dev.duffyapp.com:8000/smskeeper/resend_sms?msg_id=12345
#
@csrf_exempt
def resend_msg(request):
	form = ResendMsgForm(api_util.getRequestData(request))
	response = dict()
	if (form.is_valid()):
		msgId = form.cleaned_data['msg_id']
		keeperNumber = form.cleaned_data['from_num']

		if not keeperNumber:
			keeperNumber = settings.KEEPER_NUMBER

		message = Message.objects.get(id=msgId)
		data = json.loads(message.msg_json)

		if (message.incoming):
			requestDict = json.loads(message.msg_json)
			processing_util.processMessage(message.user.phone_number, requestDict["Body"], requestDict, keeperNumber)
		else:
			sms_util.sendMsg(message.user, data["Body"], None, keeperNumber)

		response["result"] = True
		return HttpResponse(json.dumps(response), content_type="text/json", status=200)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


def getUserDataDict(user, phoneNumToContactDict):
	if user.phone_number in phoneNumToContactDict:
		full_name = phoneNumToContactDict[user.phone_number]
	else:
		full_name = ''

	userData = {
		"id": user.id,
		"phone_number": user.phone_number,
		"name": user.name,
		"full_name": full_name,
		"source": user.signup_data_json,
		"activated": user.activated,
		"paused": user.paused,
		"created": user.added,
		"state": user.state,
		"tutorial_step": user.tutorial_step,
		"completed_tutorial": user.completed_tutorial
	}
	return userData


@login_required(login_url='/admin/login/')
def dashboard_feed(request):
	users = User.objects.all().order_by("id")
	user_dicts = []
	phoneNumList = list()
	for user in users:
		phoneNumList.append(user.phone_number)

	phoneNumToContactDict = getNameFromContactsDB(phoneNumList)

	for user in users:
		userData = getUserDataDict(user, phoneNumToContactDict)

		userData["message_stats"] = {}
		for direction in ["incoming", "outgoing"]:
			incoming = (direction == "incoming")
			messages = Message.objects.filter(user=user, incoming=incoming).order_by("-added")
			count = messages.count()
			last_message_date = None
			if count > 0:
				last_message_date = messages[0].added
			else:
				# for new users, setting it to beginning of 2015
				last_message_date = user.added
			userData["message_stats"][direction] = {
				"count": count,
				"last": last_message_date,
			}
		userData["history"] = "history?user_id=" + str(user.id)

		user_dicts.append(userData)

	user_dicts = sorted(user_dicts, key=lambda k: k['message_stats']['incoming']['last'], reverse=True)

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
				"messages": message_count,
				"user_count": user_count
			}

	responseJson = json.dumps({"users": user_dicts, "daily_stats": daily_stats}, cls=DjangoJSONEncoder)
	return HttpResponse(responseJson, content_type="text/json", status=200)


def getNameFromContactsDB(phoneNumList):
	contacts = ContactEntry.objects.values('name', 'phone_number').filter(phone_number__in=phoneNumList).distinct()

	#build a dictionary
	phoneToNameDict = dict()
	for contact in contacts:
		if contact['phone_number'] not in phoneToNameDict:
			phoneToNameDict[contact['phone_number']] = [contact['name']]
		else:
			phoneToNameDict[contact['phone_number']].append(contact['name'])
	return phoneToNameDict


@login_required(login_url='/admin/login/')
def dashboard(request):
	return render(request, "dashboard.html", None)


@jsonp
def signup_from_website(request):
	response = dict({'result': True})
	form = WebsiteRegistrationForm(api_util.getRequestData(request))
	if (form.is_valid()):
		source = form.cleaned_data['source']
		referrerCode = form.cleaned_data['referrer']
		paid = form.cleaned_data['paid']

		# clean phone number
		region_code = 'US'
		phoneNumberStr = filter(lambda x: x in string.printable, form.cleaned_data['phone_number'].encode('utf-8'))
		phoneNum = None

		for match in phonenumbers.PhoneNumberMatcher(phoneNumberStr, region_code):
			phoneNum = phonenumbers.format_number(match.number, phonenumbers.PhoneNumberFormat.E164)

		if phoneNum:
			# create account in database
			try:
				target_user = User.objects.get(phone_number=phoneNum)

				if target_user.state == keeper_constants.STATE_NOT_ACTIVATED:
					msg = "You are already on the list. Hang tight and I'll be in touch soon."
					sms_util.sendMsg(target_user, msg, None, settings.KEEPER_NUMBER)
				elif target_user.state == keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER:
					user_util.activate(target_user, "", None, settings.KEEPER_NUMBER)

			except User.DoesNotExist:
				target_user = User.objects.create(phone_number=phoneNum, signup_data_json=json.dumps({'source': source, 'referrer': referrerCode, 'paid': paid}))
				target_user.save()

				user_util.activate(target_user, "", None, settings.KEEPER_NUMBER)

				"""
				Comment out code to try always activating users
				if referrerCode:
					# First, activate this new user.
					user_util.activate(target_user, "", None, settings.KEEPER_NUMBER)

					# Next, activate the user who referred them, if they aren't activataed already
					referrerCodeUsers = User.objects.filter(invite_code=referrerCode)
					if len(referrerCodeUsers) == 1:
						referrerCodeUser = referrerCodeUsers[0]
						logger.debug("Found referring user %s" % (referrerCodeUser.id))
						if referrerCodeUser.state == keeper_constants.STATE_NOT_ACTIVATED:
							user_util.activate(referrerCodeUser, "You just jumped the line!", None, settings.KEEPER_NUMBER)
					elif len(referrerCodeUser) > 1:
						logger.error("Just found multiple users for referrerCode code %s" % referrerCode)
					else:
						logger.debug("Didn't find any referrerCodes for code %s" % referrerCode)
				else:
					if source and "fb" in source:
						user_util.activate(target_user, "", None, settings.KEEPER_NUMBER)
					else:
						not_activated.dealWithNonActivatedUser(target_user, settings.KEEPER_NUMBER)
				"""
				analytics.logUserEvent(target_user, "Website Signup", {
					"source": source,
					"referred": True if referrerCode else False
				})
		else:
			response['result'] = False
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response), content_type="application/json")

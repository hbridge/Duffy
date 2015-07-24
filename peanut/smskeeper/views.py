import json
from datetime import date, timedelta
import os
import sys
import phonenumbers
import logging
import string
import re
from time import time
from operator import add

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from common import api_util, slack_logger
from common.models import ContactEntry
from django.conf import settings
from django.contrib.auth.decorators import login_required
from django.core.serializers.json import DjangoJSONEncoder
from django.http import HttpResponse, HttpResponseRedirect
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from django.db import connection
from smskeeper import sms_util, processing_util, keeper_constants, user_util
from smskeeper.forms import UserIdForm, SmsContentForm, SendSMSForm, ResendMsgForm, WebsiteRegistrationForm
from smskeeper.models import User, Entry, Message

from smskeeper import analytics, helper_util

from smskeeper.serializers import EntrySerializer
from smskeeper.serializers import MessageSerializer
from rest_framework import generics
from rest_framework import permissions
from rest_framework import authentication

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
def keeper_app(request):
	return renderReact(request, 'keeper_app', 'keeper_app.html')


def mykeeper(request, key):
	try:
		user = User.objects.get(key="K" + key)
		return renderReact(request, 'keeper_app', 'keeper_app.html', user)
	except User.DoesNotExist:
		return HttpResponse(json.dumps({"Errors": "User not found"}), content_type="text/json", status=400)


@login_required(login_url='/admin/login/')
def history(request):
	return renderReact(request, 'history', 'history.html', context={"classifications": Message.Classifications()})


def renderReact(request, appName, templateFile="react_app.html", user=None, context=dict()):
	form = UserIdForm(api_util.getRequestData(request))
	if (form.is_valid()):
		if not user:
			user = form.cleaned_data['user']

		phoneNumToContactDict = getNameFromContactsDB([user.phone_number])

		context["user_data"] = json.dumps(getUserDataDict(user, phoneNumToContactDict), cls=DjangoJSONEncoder)
		context["development"] = settings.DEBUG
		if form.cleaned_data['development']:
			context["development"] = form.cleaned_data['development']
		context["script_name"] = appName

		return render(request, templateFile, context)
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
			message_dict["incoming"] = message.incoming
			message_dict["manual"] = message.manual
			if message.incoming:
				message_dict["classification"] = message.classification
				message_dict["auto_classification"] = message.auto_classification
				if message.classification_scores_json:
					message_dict["classification_scores"] = json.loads(message.classification_scores_json)

			messages_dicts.append(message_dict)

	return messages_dicts


def getMessagesResponseForUser(user):
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

		return HttpResponse(json.dumps(getMessagesResponseForUser(user), cls=DjangoJSONEncoder), content_type="text/json", status=200)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


class MessageDetail(generics.RetrieveUpdateAPIView):
	authentication_classes = (authentication.BasicAuthentication,)
	permission_classes = (permissions.AllowAny,)
	queryset = Message.objects.all()
	serializer_class = MessageSerializer

def entry_feed(request):
	form = UserIdForm(api_util.getRequestData(request))
	if (form.is_valid()):
		user = form.cleaned_data['user']

		entries = Entry.fetchEntries(user, hidden=None, orderByString="-updated")
		serializer = EntrySerializer(entries, many=True)
		return HttpResponse(json.dumps(serializer.data, cls=DjangoJSONEncoder), content_type="text/json", status=200)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="text/json", status=400)


class EntryList(generics.ListCreateAPIView):
	# set authentication to basic and allow any to disable CSRF protection
	authentication_classes = (authentication.BasicAuthentication,)
	permission_classes = (permissions.AllowAny,)
	queryset = Entry.objects.all()
	serializer_class = EntrySerializer


class EntryDetail(generics.RetrieveUpdateAPIView):
	# set authentication to basic and allow any to disable CSRF protection
	authentication_classes = (authentication.BasicAuthentication,)
	permission_classes = (permissions.AllowAny,)
	queryset = Entry.objects.all()
	serializer_class = EntrySerializer

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
		media = None  # add a link here to send to users

		if not keeperNumber:
			keeperNumber = user.getKeeperNumber()

		if direction == "ToUser":
			sms_util.sendMsg(user, msg, media, keeperNumber, manual=True)
		else:
			if (user.paused):
				user.paused = False
				user.save()
			requestDict = dict()
			requestDict["Body"] = msg
			requestDict["To"] = keeperNumber
			requestDict["From"] = user.phone_number
			requestDict["Manual"] = True
			processing_util.processMessage(user.phone_number, msg, requestDict, keeperNumber)
		return HttpResponse(json.dumps({"result": "success"}), content_type="text/json", status=200)
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
			slack_logger.postManualAlert(user, msg, keeper_constants.KEEPER_PROD_PHONE_NUMBERS[0], keeper_constants.SLACK_CHANNEL_MANUAL_ALERTS)
		else:
			user.paused = True
		user.save()

		return HttpResponse(json.dumps(getMessagesResponseForUser(user), cls=DjangoJSONEncoder), content_type="text/json", status=200)
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

		message = Message.objects.get(id=msgId)
		data = json.loads(message.msg_json)

		if not keeperNumber:
			keeperNumber = message.user.getKeeperNumber()

		if (message.incoming):
			if (message.user.paused):
				message.user.paused = False
				message.user.save()

			requestDict = json.loads(message.msg_json)
			requestDict["Manual"] = True
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

	newSignupData = dict()
	if user.signup_data_json:
		signupData = json.loads(user.signup_data_json)

		if 'source' in signupData and signupData['source'] != 'default':
			newSignupData['source'] = signupData['source']
		if 'referrer' in signupData and len(signupData['referrer']) > 0:
			newSignupData['ref'] = signupData['referrer']
		if 'paid' in signupData and len(signupData['paid']) > 0 and signupData['paid'] != '0':
			newSignupData['paid'] = signupData['paid']
		if 'exp' in signupData and len(signupData['exp']) > 0:
			newSignupData['exp'] = signupData['exp']

	userData = {
		"id": user.id,
		"key": user.key,
		"phone_number": user.phone_number,
		"name": user.name,
		"full_name": full_name,
		"source": json.dumps(newSignupData),
		"activated": user.activated,
		"paused": user.paused,
		"created": user.added,
		"state": user.state,
		"tutorial_step": user.tutorial_step,
		"product_id": user.product_id,
		"completed_tutorial": user.completed_tutorial,
		"timezone": str(user.getTimezone()),
		"postal_code": user.postal_code,
	}
	return userData


@login_required(login_url='/admin/login/')
def dashboard_feed(request):

	###### measuring perf
	n = len(connection.queries)
	start = time()
	######

	users = list()
	daily_stats = {}
	for days_ago in [1, 3, 7, 30]:
		date_filter = date.today() - timedelta(days=days_ago)
		daily_stats[days_ago] = {}
		for direction in ["incoming", "outgoing"]:
			incoming = (direction == "incoming")
			messages = Message.objects.filter(incoming=incoming, added__gt=date_filter)
			message_count = messages.count()
			msg_users = messages.values_list('user').distinct()
			if days_ago == 7:
				users = msg_users
			user_count = msg_users.count()
			daily_stats[days_ago][direction] = {
				"messages": message_count,
				"user_count": user_count
			}


	all_users = User.objects.all().order_by("id")
	user_dicts = []
	phoneNumList = list()
	for user in all_users:
		phoneNumList.append(user.phone_number)

	phoneNumToContactDict = getNameFromContactsDB(phoneNumList)

	users = User.objects.filter(id__in=users)

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

	##### measuring perf
	total_time = time() - start

	db_queries = len(connection.queries) - n
	if db_queries:
		db_time = reduce(add, [float(q['time'])
							   for q in connection.queries[n:]])
	else:
		db_time = 0.0

	# and backout python time
	python_time = total_time - db_time

	stats = {
		'total_time': total_time,
		'python_time': python_time,
		'db_time': db_time,
		'db_queries': db_queries,
	}
	##### End of measurement code
	
	responseJson = json.dumps({"users": user_dicts, "daily_stats": daily_stats, "stats": stats}, cls=DjangoJSONEncoder)
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
		exp = form.cleaned_data['exp']

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
					sms_util.sendMsg(target_user, msg, None, target_user.getKeeperNumber())
				elif target_user.state == keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER:
					user_util.activate(target_user, "", None, target_user.getKeeperNumber())

			except User.DoesNotExist:

				if  helper_util.isUSRegionCode(phoneNum):
					productId = keeper_constants.TODO_PRODUCT_ID
					response['medium'] = 'sms'
				else:
					productId = keeper_constants.WHATSAPP_TODO_PRODUCT_ID
					response['medium'] = 'whatsapp'
				tutorial = None

				target_user = user_util.createUser(phoneNum, json.dumps({'source': source, 'referrer': referrerCode, 'paid': paid, 'exp': exp}), None, productId)
				user_util.activate(target_user, "", tutorial, target_user.getKeeperNumber())

				logger.debug("User %s: Just created user with productId %s and keeperNumber %s" % (target_user.id, target_user.product_id, target_user.getKeeperNumber()))

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
				if 'no-js' in source:
					return HttpResponseRedirect('http://getkeeper.com/')
		else:
			response['result'] = False
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response), content_type="application/json")


@login_required(login_url='/admin/login/')
def message_classification_csv(request):
	classified_messages = Message.objects.filter(
		classification__isnull=False).exclude(classification__in='nocategory').order_by("id")

	# column headers
	response = 'text, classification\n'

	# message rows
	for message in classified_messages:
		if message.classification == "nocategory" or not message.getBody():
			continue
		response += '"%s",%s\n' % (cleanBodyText(message.getBody()), message.classification)

	return HttpResponse(response, content_type="text/text", status=200)


def cleanBodyText(text):
	result = re.sub(ur'[\n"\u201d]', '', text)
	return result


def classified_users(request):
	user_list = []
	for i in range(1000, 1150):
		user_list.append(i)

	users = User.objects.filter(id__in=user_list)
	classifiedUserIds = list()

	# We filter by product 1 users since we want to correctly emulate them in the tutorial
	for user in users:
		if user.product_id == keeper_constants.TODO_PRODUCT_ID:
			classifiedUserIds.append(user.id)

	return HttpResponse(json.dumps({"users": classifiedUserIds}), content_type="text/text", status=200)

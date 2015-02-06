import time
import json
import datetime
import os
import pytz
import random
import logging

from django.http import HttpResponse
from django.db.models import Q
from django.contrib.gis.geos import Point, fromstr
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.http import Http404
from django.db import IntegrityError, connection

from peanut.settings import constants

from common.models import Photo, User, SmsAuth, Strand, NotificationLog, ContactEntry, FriendConnection, StrandNeighbor, Action, LocationRecord, ShareInstance, ApiCache
from common.serializers import UserSerializer

from common import api_util, serializers, stats_util

from strand import geo_util, notifications_util, friends_util, strands_util, users_util, swaps_util
from strand.forms import UserIdAndStrandIdForm, RegisterAPNSTokenForm, UpdateUserLocationForm, SendSmsCodeForm, AuthPhoneForm, OnlyUserIdForm

from ios_notifications.models import APNService, Device, Notification

from async import neighboring, popcaches

logger = logging.getLogger(__name__)


def getBuildNumForUser(user):
	if user.last_build_info:
		return int(user.last_build_info.split('-')[1])
	else:
		return 4000

def getAllIdsInFeedObjects(feedObjects):
	peopleIds = set()
	for obj in feedObjects:
		if "actor_ids" in obj:
			peopleIds.update(obj["actor_ids"])
		if "user" in obj:
			peopleIds.add(obj["user"])
		if "objects" in obj:
			peopleIds.update(getAllIdsInFeedObjects(obj["objects"]))
	return list(peopleIds)


#####################################################################################
#################################  EXTERNAL METHODS  ################################
#####################################################################################


# ----------------------- FEED ENDPOINTS --------------------

"""
	Returns a string of json
"""
def runCachedFeed(cacheName, user, num):
	useCache = True
	try:
		apiCache = ApiCache.objects.get(user=user)

		if not getattr(apiCache, cacheName):
			useCache = False
	except ApiCache.DoesNotExist:
		useCache = False

	if useCache:
		responseStr = getattr(apiCache, cacheName)

		if num:
			responseObjects = json.loads(responseStr)
			responseObjects["timestamp"] = int(time.time())

			responseObjects["objects"] = responseObjects["objects"][:num]
			responseStr = json.dumps(responseObjects)
		else:
			# Manually put in the timestamp into the json so we don't have to read then write the json
			timestampStr = '"timestamp": %s,' %  int(time.time())
			if not responseStr:
				responseStr = "{%s}" % timestampStr
			else:
				responseStr = responseStr[:1] + timestampStr + responseStr[1:]
		return responseStr
	else:
		return None

"""
	Return the Duffy JSON for the strands a user has that are private and unshared
"""
def private_strands(request):
	stats_util.startProfiling()
	response = dict({'result': True})
	responseStr = ""

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		num = form.cleaned_data['num']

		if num:
			num = 50
		
		result = runCachedFeed("private_strands_data", user, num)
		if result == None:
			objs = swaps_util.getFeedObjectsForPrivateStrands(user)

			response['objects'] = objs
			response['timestamp'] = datetime.datetime.utcnow()
			
			responseStr = json.dumps(response, cls=api_util.DuffyJsonEncoder)
		else:
			responseStr = result
		stats_util.printStats("private-end")
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(responseStr, content_type="application/json")

"""
	Returns back the suggested shares
"""
def swaps(request):
	stats_util.startProfiling()
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		responseObjects = list()
		user = form.cleaned_data['user']

		swapsObjects = swaps_util.getFeedObjectsForSwaps(user)
		responseObjects.extend(swapsObjects)

		stats_util.printStats("swaps-objects")		

		responseObjects.append(swaps_util.getPeopleListEntry(user, getAllIdsInFeedObjects(swapsObjects)))
		stats_util.printStats("swaps-actors")
		stats_util.printStats("swaps-end")
		response['objects'] = responseObjects
		response["timestamp"] = datetime.datetime.now()
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")


def swap_inbox(request):
	stats_util.startProfiling()
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		responseObjects = list()
		user = form.cleaned_data['user']
		num = form.cleaned_data['num']

		if num:
			num = 25

		# Add in buffer for the last timestamp, or if not sent in, use long ago date
		if form.cleaned_data['last_timestamp']:
			lastTimestamp = form.cleaned_data['last_timestamp'] - datetime.timedelta(seconds=10)
			inboxObjects = swaps_util.getFeedObjectsForInbox(user, lastTimestamp, num)
			responseObjects.extend(inboxObjects)
			popcaches.processInboxFull.delay(user.id)
		else:
			result = runCachedFeed("inbox_data", user, num)
			if result == None:
				lastTimestamp = datetime.datetime.fromtimestamp(0)
				inboxObjects = swaps_util.getFeedObjectsForInbox(user, lastTimestamp, num)
				popcaches.processInboxFull.delay(user.id)
			else:
				inboxObjects = json.loads(result)["objects"]
			responseObjects.extend(inboxObjects)

		responseObjects.append(swaps_util.getPeopleListEntry(user, getAllIdsInFeedObjects(inboxObjects)))

		stats_util.printStats("swaps_inbox-end")
		response["objects"] = responseObjects
		response["timestamp"] = datetime.datetime.now()
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

def actions_list(request):
	stats_util.startProfiling()
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		responseObjects = list()
		user = form.cleaned_data['user']

		actionsObjects = swaps_util.getActionsList(user)

		responseObjects.append({'type': 'actions_list', 'actions': actionsObjects})
		stats_util.printStats("actions-end")

		responseObjects.append(swaps_util.getPeopleListEntry(user, getAllIdsInFeedObjects(actionsObjects)))
		response['objects'] = responseObjects
		response["timestamp"] = datetime.datetime.now()
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

#   -------------------------  OTHER ENDPOINTS ---------------------



"""
	Registers a user's current location (and only stores the last location)
"""
def update_user_location(request):
	response = dict({'result': True})
	form = UpdateUserLocationForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		lon = form.cleaned_data['lon']
		lat = form.cleaned_data['lat']
		timestamp = form.cleaned_data['timestamp']
		accuracy = form.cleaned_data['accuracy']
		
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		
		if ((not lon == 0) or (not lat == 0)):
			record = LocationRecord(user = user, point = fromstr("POINT(%s %s)" % (lon, lat)), timestamp = timestamp, accuracy = accuracy)
			record.save()

			neighboring.processLocationRecordIds.delay([record.id])
			
			if ((user.last_location_timestamp and timestamp and timestamp > user.last_location_timestamp) or not user.last_location_timestamp):
				user.last_location_point = fromstr("POINT(%s %s)" % (lon, lat))

				if timestamp:
					user.last_location_timestamp = timestamp
				else:
					user.last_location_timestamp = now

				user.last_location_accuracy = accuracy
							
				# We're saving last build info here since we are already writing to the user row in the database
				if form.cleaned_data['build_id'] and form.cleaned_data['build_number']:
					# if last_build_info is empty or if either build_id or build_number is not in last_build_info
					#    update last_build_info
					if ((not user.last_build_info) or 
						form.cleaned_data['build_id'] not in user.last_build_info or 
						str(form.cleaned_data['build_number']) not in user.last_build_info):
						user.last_build_info = "%s-%s" % (form.cleaned_data['build_id'], form.cleaned_data['build_number'])
						logger.info("Build info updated to %s" % (user.last_build_info))
			
				user.save()
				logger.info("Location updated for user %s. %s: %s, %s, %s" % (user.id, datetime.datetime.utcnow().replace(tzinfo=pytz.utc), user.id, user.last_location_point, accuracy))
			else:
				logger.info("Location NOT updated for user %s. Old Timestamp. %s: %s, %s" % (user.id, timestamp, user.id, str((lon, lat))))
		else:
			logger.info("Location NOT updated for user %s. Lat/Lon Zero. %s: %s, %s" % (user.id, datetime.datetime.utcnow().replace(tzinfo=pytz.utc), user.id, str((lon, lat))))

	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response), content_type="application/json")


"""
	Receives device tokens for APNS notifications
"""
def register_apns_token(request):
	response = dict({'result': True})
	form = RegisterAPNSTokenForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		deviceToken = form.cleaned_data['device_token'].replace(' ', '').replace('<', '').replace('>', '')

		# TODO (Aseem): Make this more efficient. Assume nothing!
		user.device_token = deviceToken
		apnsDev = APNService.objects.get(id=constants.IOS_NOTIFICATIONS_DEV_APNS_ID)
		apnsProd = APNService.objects.get(id=constants.IOS_NOTIFICATIONS_PROD_APNS_ID)
		apnsDerekDev = APNService.objects.get(id=constants.IOS_NOTIFICATIONS_DEREK_DEV_APNS_ID)
		apnsEnterpriseProd = APNService.objects.get(id=constants.IOS_NOTIFICATIONS_ENTERPRISE_PROD_APNS_ID)
		apnsEnterpriseDev = APNService.objects.get(id=constants.IOS_NOTIFICATIONS_ENTERPRISE_DEV_APNS_ID)

		devices = Device.objects.filter(token=deviceToken)

		if (len(devices) == 0):
			Device.objects.create(token=deviceToken, is_active=True, service=apnsDev)
			Device.objects.create(token=deviceToken, is_active=True, service=apnsDerekDev)
			Device.objects.create(token=deviceToken, is_active=True, service=apnsProd)
			Device.objects.create(token=deviceToken, is_active=True, service=apnsEnterpriseProd)			
			Device.objects.create(token=deviceToken, is_active=True, service=apnsEnterpriseDev)
		else:
			for device in devices:
				if (not(device.token == deviceToken)):
					device.token = deviceToken
				if (not device.is_active):
					device.is_active = True
				device.save()

		if form.cleaned_data['build_id'] and form.cleaned_data['build_number']:
			# if last_build_info is empty or if either build_id or build_number is not in last_build_info
			#    update last_build_info
			buildId = form.cleaned_data['build_id']
			buildNum = form.cleaned_data['build_number']
			if ((not user.last_build_info) or 
				buildId not in user.last_build_info or 
				str(buildNum) not in user.last_build_info):
				user.last_build_info = "%s-%s" % (buildId, buildNum)
				logger.info("Build info updated to %s" % (user.last_build_info))

		user.save()
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Sends a notification to the device based on the user_id
"""

def send_notifications_test(request):
	response = dict({'result': True})
	data = api_util.getRequestData(request)

	msg = None
	customPayload = dict()

	if data.has_key('user_id'):
		userId = data['user_id']
		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			return api_util.returnFailure(response, "user_id not found")
	else:
		return api_util.returnFailure(response, "Need user_id")

	if data.has_key('msg'):
		msg = str(data['msg'])

	if data.has_key('msgTypeId'):
		msgTypeId = int(data['msgTypeId'])
	else:
		return api_util.returnFailure(response, "Need msgTypeId")

	if data.has_key('id'):
		customPayload['id'] = int(data['id'])

	if data.has_key('share_instance_id'):
		customPayload['share_instance_id'] = int(data['share_instance_id'])

	notifications_util.sendNotification(user, msg, msgTypeId, customPayload)

	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Sends a test text message to a phone number
"""

def send_sms_test(request):
	response = dict({'result': True})
	data = api_util.getRequestData(request)

	if data.has_key('phone'):
		phone = data['phone']
	else:
		phone = '6505759014'

	if data.has_key('body'):
		bodytext = data['body']
	else:
		bodytext = "Test msg from Strand/send_sms_test"
	
	notifications_util.sendSMS(phone, bodytext)
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Sends SMS code to the given phone number.

	Right now theres no SPAM protection for numbers.  Can be added by looking at the last time
	a code was sent to a number
"""
def send_sms_code(request):
	response = dict({'result': True})

	form = SendSmsCodeForm(api_util.getRequestData(request))
	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['phone_number'])

		if "555555" not in phoneNumber:
			accessCode = random.randrange(1000, 10000)

			msg = "Your Swap code is:  %s" % (accessCode)
	
			notifications_util.sendSMS(phoneNumber, msg)
			SmsAuth.objects.create(phone_number = phoneNumber, access_code = accessCode)
		else:
			response['debug'] = "Skipped"
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Call to authorize a phone with an sms code.  The SMS code should have been sent with send_sms_code
	above already.

	This then takes in the display_name and creates a user account
"""
@csrf_exempt
def auth_phone(request):
	response = dict({'result': True})
	form = AuthPhoneForm(api_util.getRequestData(request))

	timeWithinMinutes = 10

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['phone_number'])
		accessCode = form.cleaned_data['sms_access_code']
		displayName = form.cleaned_data['display_name']
		phoneId = form.cleaned_data['phone_id']

		if "555555" not in phoneNumber:
			timeWithin = datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(minutes=timeWithinMinutes)

			smsAuth = SmsAuth.objects.filter(phone_number=phoneNumber, access_code=accessCode)

			if len(smsAuth) == 0 or len(smsAuth) > 1:
				return HttpResponse(json.dumps({'access_code': 'Invalid code'}), content_type="application/json", status=400)
			elif smsAuth[0].user_created:
				return HttpResponse(json.dumps({'access_code': 'Code already used'}), content_type="application/json", status=400)
			elif smsAuth[0].added < timeWithin:
				return HttpResponse(json.dumps({'access_code': 'Code expired'}), content_type="application/json", status=400)
			else:
				# TODO(Derek):  End of August, change returnIfExists to False, so we start archiving again
				user = users_util.createStrandUserThroughSmsAuth(phoneNumber, displayName, smsAuth[0], form.cleaned_data['build_number'])
				serializer = UserSerializer(user)
				response['user'] = serializer.data
		else:
			if accessCode == 2345:
				user = users_util.createStrandUserThroughSmsAuth(phoneNumber, displayName, None, form.cleaned_data['build_number'])
				serializer = UserSerializer(user)
				response['user'] = serializer.data
			else:
				return HttpResponse(json.dumps({'access_code': 'Invalid code'}), content_type="application/json", status=400)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")



def nothing(request):
	return HttpResponse(json.dumps(dict()), content_type="application/json")


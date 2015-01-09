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

from common.models import Photo, User, SmsAuth, Strand, NotificationLog, ContactEntry, FriendConnection, StrandNeighbor, Action, LocationRecord, ShareInstance
from common.serializers import UserSerializer

from common import api_util, cluster_util, serializers

from strand import geo_util, notifications_util, friends_util, strands_util, users_util, swaps_util
from strand.forms import UserIdAndStrandIdForm, RegisterAPNSTokenForm, UpdateUserLocationForm, SendSmsCodeForm, AuthPhoneForm, OnlyUserIdForm

from ios_notifications.models import APNService, Device, Notification


logger = logging.getLogger(__name__)

def uniqueObjects(seq, idfun=None): 
   # order preserving
   if idfun is None:
	   def idfun(x): return x.id
   seen = {}
   result = []
   for item in seq:
	   marker = idfun(item)
	   # in old Python versions:
	   # if seen.has_key(marker)
	   # but in new ones:
	   if marker in seen: continue
	   seen[marker] = 1
	   result.append(item)
   return result



def getFriendsObjectData(userId, users, includePhone = True):
	if not isinstance(users, list) and not isinstance(users, set):
		users = [users]

	friendList = friends_util.getFriendsIds(userId)

	userData = list()
	for user in users:
		if user.id in friendList:
			relationship = constants.FEED_OBJECT_TYPE_RELATIONSHIP_FRIEND
		else:
			relationship = constants.FEED_OBJECT_TYPE_RELATIONSHIP_USER
		
		entry = {'display_name': user.display_name, 'id': user.id, constants.FEED_OBJECT_TYPE_RELATIONSHIP: relationship}

		if includePhone:
			entry['phone_number'] = user.phone_number

		userData.append(entry)

	return userData


"""
	This turns a list of list of photos into groups that contain a title and cluster.

	We do all the photos at once so we can load up the sims cache once

	Takes in list of dicts:
	[
		{
			'photos': [photo1, photo2]
			'metadata' : {'strand_id': 12}
		},
		{
			'photos': [photo1, photo2]
			'metadata' : {'strand_id': 17}
		}
	]

	Returns format of:
	[
		{
			'clusters': clusters
			'metadata': {'title': blah,
						 'subtitle': blah2,
						 'strand_id': 12
						}
		},
		{
			'clusters': clusters
			'metadata': {'title': blah3,
						 'subtitle': blah4,
						 'strand_id': 17
						}
		},
	]
"""
def getFormattedGroups(groups, simCaches = None):
	if len(groups) == 0:
		return []

	output = list()

	photoIds = list()
	for group in groups:
		for photo in group['photos']:
			photoIds.append(photo.id)

	# Fetch all the similarities at once so we can process in memory
	a = datetime.datetime.now()
	if simCaches == None:
		simCaches = cluster_util.getSimCaches(photoIds)

	for group in groups:
		if len(group['photos']) == 0:
			continue

		clusters = cluster_util.getClustersFromPhotos(group['photos'], constants.DEFAULT_CLUSTER_THRESHOLD, 0, simCaches)

		location = strands_util.getBestLocationForPhotos(group['photos'])
		if not location:
			location = "Location Unknown"

		metadata = group['metadata']
		metadata.update({'subtitle': location, 'location': location})
		
		output.append({'clusters': clusters, 'metadata': metadata})

	return output

def getObjectsDataFromGroups(groups):
	# Pass in none for actions because there are no actions on private photos so don't use anything
	formattedGroups = getFormattedGroups(groups)
	
	# Lastly, we turn our groups into sections which is the object we convert to json for the api
	objects = api_util.turnFormattedGroupsIntoFeedObjects(formattedGroups, 10000)

	return objects

def getBuildNumForUser(user):
	if user.last_build_info:
		return int(user.last_build_info.split('-')[1])
	else:
		return 4000

def getObjectsDataForSpecificTime(user, lower, upper, title, rankNum):
	strands = Strand.objects.prefetch_related('photos', 'user').filter(user=user).filter(private=True).filter(suggestible=True).filter(contributed_to_id__isnull=True).filter(Q(first_photo_time__gt=lower) & Q(first_photo_time__lt=upper))

	groups = swaps_util.getGroupsDataForPrivateStrands(user, strands, constants.FEED_OBJECT_TYPE_SWAP_SUGGESTION, neighborStrandsByStrandId=dict(), neighborUsersByStrandId=dict())
	groups = sorted(groups, key=lambda x: x['metadata']['time_taken'], reverse=True)

	objects = getObjectsDataFromGroups(groups)

	for suggestion in objects:
		suggestion['suggestible'] = True
		suggestion['suggestion_type'] = "timed-%s" % (title)
		suggestion['title'] = title
		suggestion['suggestion_rank'] = rankNum
		rankNum += 1
	return objects


# Need to create a key that is sortable, consistant (to deal with partial updates) and handles
# many photos shared at once
def getSortRanking(user, shareInstance, actions):
	lastTimestamp = None

	if shareInstance.user_id == user.id:
		lastTimestamp = shareInstance.shared_at_timestamp

	for action in actions:
		if ((action.action_type == constants.ACTION_TYPE_PHOTO_EVALUATED and
			action.user_id == user.id) or
			action.action_type == constants.ACTION_TYPE_COMMENT):
			if not lastTimestamp or action.added > lastTimestamp:
				lastTimestamp = action.added


	if not lastTimestamp:
		# this will happen for photos that need to be evaluated
		return 0
		
	a = (long(lastTimestamp.strftime('%s')) % 1000000000) * 10000000
	b = long(shareInstance.photo.time_taken.strftime('%s')) % 10000000

	return -1 * (a + b)


#####################################################################################
#################################  EXTERNAL METHODS  ################################
#####################################################################################


requestStartTime = None
lastCheckinTime = None
lastCheckinQueryCount = 0

def startProfiling():
	global requestStartTime
	global lastCheckinTime
	global lastCheckinQueryCount
	requestStartTime = datetime.datetime.now()
	lastCheckinTime = requestStartTime
	lastCheckinQueryCount = 0

def printStats(title, printQueries = False):
	global lastCheckinTime
	global lastCheckinQueryCount

	now = datetime.datetime.now()
	msTime = ((now-lastCheckinTime).microseconds / 1000 + (now-lastCheckinTime).seconds * 1000)
	lastCheckinTime = now

	queryCount = len(connection.queries) - lastCheckinQueryCount
	

	print "%s took %s ms and did %s queries" % (title, msTime, queryCount)

	if printQueries:
		print "QUERIES for %s" % title
		for query in connection.queries[lastCheckinQueryCount:]:
			print query

	lastCheckinQueryCount = len(connection.queries)


# ----------------------- FEED ENDPOINTS --------------------

"""
	Return the Duffy JSON for the strands a user has that are private and unshared
"""
def private_strands(request):
	startProfiling()
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']

		printStats("private-1")
		
		strands = list(Strand.objects.prefetch_related('photos', 'users', 'photos__user').filter(user=user).filter(private=True))

		printStats("private-2")

		deletedSomething = False
		for strand in strands:
			if len(strand.photos.all()) == 0:
				logging.error("Found strand %s with no photos in private strands, deleting.  users are %s" % (strand.id, strand.users.all()))
				strand.delete()
				deletedSomething = True

		if deletedSomething:
			strands = list(Strand.objects.prefetch_related('photos', 'users', 'photos__user').filter(user=user).filter(private=True))

		friends = friends_util.getFriends(user.id)
		
		groups = swaps_util.getGroupsDataForPrivateStrands(user, strands, constants.FEED_OBJECT_TYPE_STRAND, friends=friends, locationRequired = True)
		
		response['objects'] = getObjectsDataFromGroups(groups)	
		printStats("private-3")
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

def swap_inbox(request):
	startProfiling()
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		num = form.cleaned_data['num']

		# Add in buffer for the last timestamp, or if not sent in, use long ago date
		if form.cleaned_data['last_timestamp']:
			lastTimestamp = form.cleaned_data['last_timestamp'] - datetime.timedelta(seconds=10)
		else:
			lastTimestamp = datetime.datetime.fromtimestamp(0)

		responseObjects = list()

		# Grab all share instances we want.  Might filter by a last timestamp for speed
		shareInstances = ShareInstance.objects.prefetch_related('photo', 'users', 'photo__user').filter(users__in=[user.id]).filter(updated__gt=lastTimestamp).order_by("-updated", "id")
		if num:
			shareInstances = shareInstances[:num]

		# The above search won't find photos that this user has evaluated if the last_action_timestamp
		# is before the given lastTimestamp
		# So in that case, lets search for all the actions since that timestamp and add those
		# ShareInstances into the mix to be sorted
		if form.cleaned_data['last_timestamp']:
			recentlyEvaluatedActions = Action.objects.prefetch_related('share_instance', 'share_instance__photo', 'share_instance__users', 'share_instance__photo__user').filter(user=user).filter(updated__gt=lastTimestamp).filter(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED).order_by('-added')

			shareInstanceIds = ShareInstance.getIds(shareInstances)
			shareInstances = list(shareInstances)
			for action in recentlyEvaluatedActions:
				if action.share_instance_id and action.share_instance_id not in shareInstanceIds:
					shareInstances.append(action.share_instance)
			
		# Now filter out anything that doesn't have a thumb...unless its your own photo
		filteredShareInstances = list()
		for shareInstance in shareInstances:
			if shareInstance.user_id == user.id:
				filteredShareInstances.append(shareInstance)
			elif shareInstance.photo.thumb_filename:
				filteredShareInstances.append(shareInstance)
		shareInstances = filteredShareInstances
		
		# Now grab all the actions for these ShareInstances (comments, evals, likes)
		shareInstanceIds = ShareInstance.getIds(shareInstances)
		printStats("swaps_inbox-1")

		actions = Action.objects.filter(share_instance_id__in=shareInstanceIds)
		actionsByShareInstanceId = dict()
		
		for action in actions:
			if action.share_instance_id not in actionsByShareInstanceId:
				actionsByShareInstanceId[action.share_instance_id] = list()
			actionsByShareInstanceId[action.share_instance_id].append(action)

		printStats("swaps_inbox-2")

		# Loop through all the share instances and create the feed data
		for shareInstance in shareInstances:
			actions = list()
			if shareInstance.id in actionsByShareInstanceId:
				actions = actionsByShareInstanceId[shareInstance.id]

			actions = uniqueObjects(actions)
			objectData = serializers.objectDataForShareInstance(shareInstance, actions, user)

			# suggestion_rank here for backwards compatibility, remove upon next mandatory updatae after Jan 2
			objectData['sort_rank'] = getSortRanking(user, shareInstance, actions)
			objectData['suggestion_rank'] = objectData['sort_rank']
			responseObjects.append(objectData)

		responseObjects = sorted(responseObjects, key=lambda x: x['sort_rank'])
		
		count = 0
		for responseObject in responseObjects:
			responseObject["debug_rank"] = count
			count += 1

		printStats("swaps_inbox-3")

		# Add in the list of all friends at the end
		peopleIds = friends_util.getFriendsIds(user.id)

		# Also add in all of the actors they're dealing with
		for obj in responseObjects:
			peopleIds.extend(obj['actor_ids'])

		people = set(User.objects.filter(id__in=peopleIds))

		peopleEntry = {'type': constants.FEED_OBJECT_TYPE_FRIENDS_LIST, 'share_instance': -1, 'people': getFriendsObjectData(user.id, people, True)}		
		responseObjects.append(peopleEntry)

		printStats("swaps_inbox-end")

		response["objects"] = responseObjects
		response["timestamp"] = datetime.datetime.now()
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

def actions_list(request):
	startProfiling()
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		responseObjects = list()

		shareInstances = ShareInstance.objects.filter(users__in=[user.id]).order_by("-updated", "id")[:50]

		shareInstanceIds = ShareInstance.getIds(shareInstances)
		
		actions = Action.objects.prefetch_related('user', 'strand').exclude(user=user).filter(Q(action_type=constants.ACTION_TYPE_FAVORITE) | Q(action_type=constants.ACTION_TYPE_COMMENT)).filter(share_instance_id__in=shareInstanceIds).order_by("-added")

		actionsData = list()
		for action in actions:
			actionsData.append(serializers.actionDataForApiSerializer(action))

		actionsData = {'type': 'actions_list', 'actions': actionsData}

		response['objects'] = [actionsData]
		printStats("actions-end")

		user.last_actions_list_request_timestamp = datetime.datetime.utcnow()
		user.save()
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")


"""
	Returns back the suggested shares
"""
def swaps(request):
	startProfiling()
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		responseObjects = list()

		# Now do neighbor suggestions
		friendsIdList = friends_util.getFriendsIds(user.id)

		strandNeighbors = StrandNeighbor.objects.filter((Q(strand_1_user_id=user.id) & Q(strand_2_user_id__in=friendsIdList)) | (Q(strand_1_user_id__in=friendsIdList) & Q(strand_2_user_id=user.id)))
		strandIds = list()
		for strandNeighbor in strandNeighbors:
			if strandNeighbor.strand_1_user_id == user.id:
				strandIds.append(strandNeighbor.strand_1_id)
			else:
				strandIds.append(strandNeighbor.strand_2_id)

		strands = Strand.objects.prefetch_related('photos').filter(user=user).filter(private=True).filter(suggestible=True).filter(id__in=strandIds).order_by('-first_photo_time')[:20]

		# The prefetch for 'user' took a while here so just do it manually
		for strand in strands:
			for photo in strand.photos.all():
				photo.user = user
				
		strands = list(strands)
		printStats("swaps-strands-fetch")

		neighborStrandsByStrandId, neighborUsersByStrandId = swaps_util.getStrandNeighborsCache(strands, friends_util.getFriends(user.id))
		printStats("swaps-neighbors-cache")

		locationBasedGroups = swaps_util.getGroupsDataForPrivateStrands(user, strands, constants.FEED_OBJECT_TYPE_SWAP_SUGGESTION, neighborStrandsByStrandId = neighborStrandsByStrandId, neighborUsersByStrandId = neighborUsersByStrandId, locationRequired = True)

		printStats("swap-groups")
	
		locationBasedGroups = filter(lambda x: x['metadata']['suggestible'], locationBasedGroups)
		locationBasedGroups = sorted(locationBasedGroups, key=lambda x: x['metadata']['time_taken'], reverse=True)
		locationBasedGroups = swaps_util.filterEvaluatedPhotosFromGroups(user, locationBasedGroups)
		locationBasedSuggestions = getObjectsDataFromGroups(locationBasedGroups)

		rankNum = 0
		locationBasedIds = list()
		for suggestion in locationBasedSuggestions:
			suggestion['suggestion_rank'] = rankNum
			suggestion['suggestion_type'] = "friend-location"
			rankNum += 1
			locationBasedIds.append(suggestion['id'])

		for objects in locationBasedSuggestions:
			responseObjects.append(objects)
		printStats("swaps-location-suggestions")
		
		# Last resort, try throwing in recent photos
		if len(responseObjects) < 3:
			now = datetime.datetime.utcnow()
			lower = now - datetime.timedelta(days=7)

			lastWeekObjects = getObjectsDataForSpecificTime(user, lower, now, "Last Week", rankNum)
			rankNum += len(lastWeekObjects)
		
			for objects in lastWeekObjects:
				responseObjects.append(objects)

			printStats("swaps-recent-photos")
		response['objects'] = responseObjects
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


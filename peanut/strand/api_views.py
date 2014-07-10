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

from peanut.settings import constants

from common.models import Photo, User, Neighbor, SmsAuth
from common.serializers import UserSerializer

from common import api_util, cluster_util

from strand import geo_util, notifications_util
from strand.forms import GetJoinableStrandsForm, GetNewPhotosForm, RegisterAPNSTokenForm, UpdateUserLocationForm, GetFriendsNearbyMessageForm, SendSmsCodeForm, AuthPhoneForm

from ios_notifications.models import APNService, Device, Notification

logger = logging.getLogger(__name__)

def getGroupForPhoto(photo, clusters):
	for cluster in clusters:
		if photo in cluster:
			return cluster
	return None

def removeDups(seq, idFunction=None): 
   # order preserving
   if idFunction is None:
	   def idFunction(x): return x
   seen = {}
   result = []
   for item in seq:
	   id = idFunction(item)
	   if id in seen: continue
	   seen[id] = 1
	   result.append(item)
   return result

def getBestLocation(photo):
	if photo.twofishes_data:
		twoFishesData = json.loads(photo.twofishes_data)
		bestLocationName = None
		bestWoeType = 100
		for data in twoFishesData["interpretations"]:
			if "woeType" in data["feature"]:
				# https://github.com/foursquare/twofishes/blob/master/interface/src/main/thrift/geocoder.thrift
				if data["feature"]["woeType"] < bestWoeType:
					bestLocationName = data["feature"]["displayName"]
					bestWoeType = data["feature"]["woeType"]
					if bestLocationName:
						return bestLocationName
					else:
						return photo.location_city
	else:
		return "Earth"
"""
	This turns a list of list of photos into groups that contain a title and cluster.

	We do all the photos at once so we can load up the sims cache once

	Returns format of:
	[
		{
			'title': blah
			'clusters': clusters
		},
		{
			'title': blah2
			'clusters': clusters
		},
	]
"""
def getGroups(groupings):
	if len(groupings) == 0:
		return []

	output = list()

	photoIds = list()
	for group in groupings:
		for photo in group:
			photoIds.append(photo.id)

	# Fetch all the similarities at once so we can process in memory
	simCaches = cluster_util.getSimCaches(photoIds)

	for group in groupings:
		if len(group) == 0:
			continue
			
		# Grab title from the location_city of a photo...but find the first one that has
		#   a valid location_city
		title = None
		i = 0
		while (not title) and i < len(group):
			title = getBestLocation(group[i])
			i += 1
			
		clusters = cluster_util.getClustersFromPhotos(group, constants.DEFAULT_CLUSTER_THRESHOLD, constants.DEFAULT_DUP_THRESHOLD, simCaches)

		output.append({'title': title, 'clusters': clusters})
	return output
	
"""
	Get photos that have neighbor entries for this user and are after the given startTime
"""
def getNeighboredPhotos(userId, startTime):
	# Get all neighbors for this user's photos
	neighbors = Neighbor.objects.select_related().filter(Q(user_1_id=userId) | Q(user_2_id=userId)).filter(Q(photo_1__time_taken__gt=startTime) | Q(photo_2__time_taken__gt=startTime)).order_by('photo_1')

	latestPhotos = list()

	# For each neighbor, find the other people's photos that were taken after the given start time
	for neighbor in neighbors:
		if neighbor.user_1_id == userId and neighbor.photo_2.time_taken > startTime:
			latestPhotos.append(neighbor.photo_2)
		elif neighbor.user_2_id == userId and neighbor.photo_1.time_taken > startTime:
			latestPhotos.append(neighbor.photo_1)
			
	uniquePhotos = removeDups(latestPhotos, lambda x: x.id)

	return uniquePhotos

def neighbors(request):
	response = dict({'result': True})
	data = api_util.getRequestData(request)

	if data.has_key('user_id'):
		userId = int(data['user_id'])
		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			return api_util.returnFailure(response, "user_id not found")
	else:
		return api_util.returnFailure(response, "Need user_id")

	results = Neighbor.objects.select_related().exclude(user_1_id=1).exclude(user_2_id=1).filter(Q(user_1=user) | Q(user_2=user)).order_by('photo_1')

	# Creates a list of lists for the sections then groups.
	# We'll first get this list setup, de-duped and sorted
	groupings = list()
	for neighbor in results:
		group = getGroupForPhoto(neighbor.photo_1, groupings)

		if (group):
			# If the first photo is in a cluster, see if the other photo is in there already
			#   if it isn't, and this isn't a dup, then add photo_2 in
			if neighbor.photo_2 not in group:
				group.append(neighbor.photo_2)
		else:
			# If the first photo isn't in a cluster, see if the second one is
			group = getGroupForPhoto(neighbor.photo_2, groupings)

			if (group):
				# If the second photo is in a cluster and this isn't a dup then add in
				group.append(neighbor.photo_1)
			else:
				# If neither photo is in a cluster, we create a new one
				group = [neighbor.photo_1, neighbor.photo_2]

				groupings.append(group)

	sortedGroups = list()
	for group in groupings:
		group = sorted(group, key=lambda x: x.time_taken, reverse=True)

		# This is a crappy hack.  What we'd like to do is define a dup as same time_taken and same
		#   location_point.  But a bug in mysql looks to be corrupting the lat/lon we fetch here.
		#   So using location_city instead.  This means we might cut out some photos that were taken
		#   at the exact same time in the same city
		uniqueGroup = removeDups(group, lambda x: (x.time_taken, x.location_city))
		sortedGroups.append(uniqueGroup)

	# now sort clusters by the time_taken of the first photo in each cluster
	sortedGroups = sorted(sortedGroups, key=lambda x: x[0].time_taken, reverse=True)

	# Try to find recent photos
	# If there are no previous groups, then fetch all photos and call them recent
	# This query isn't executed raw, we add a filter for time_taken if there's any groups
	# If there aren't any groups then the user probably doesn't have many photos
	recentPhotos = Photo.objects.filter(user_id=userId).order_by("-time_taken")
	if len(sortedGroups) > 0 and len (sortedGroups[0]) > 0:
		lastPhotoTime = sortedGroups[0][0].time_taken
		recentPhotos = recentPhotos.filter(time_taken__gt=lastPhotoTime)

	haveRecentPhotos = len(recentPhotos) > 0

	if haveRecentPhotos:
		sortedGroups.insert(0, recentPhotos)

	# Now see if there are any non-neighbored photos
	# These are shown on the web view as Lock symbols
	if user.last_location_point:
		nonNeighboredPhotos = getNonNeighboredPhotos(userId, user.last_location_point.x, user.last_location_point.y)
		haveNonNeighboredPhotos = len(nonNeighboredPhotos) > 0
	else:
		haveNonNeighboredPhotos = False

	if haveNonNeighboredPhotos:
		sortedGroups.insert(0, nonNeighboredPhotos)

	# Now we have to turn into our Duffy JSON, first, convert into the right format
	groups = getGroups(sortedGroups)

	# Now we need to update the titles for the groups before we turn it into sections
	if haveRecentPhotos and haveNonNeighboredPhotos:
		groups[0]['title'] = "Locked"
		groups[1]['title'] = "Recent"
	elif haveRecentPhotos:
		groups[0]['title'] = "Recent"
	elif haveNonNeighboredPhotos:
		groups[0]['title'] = "Locked"

	# Lastly, we turn our groups into sections which is the object we convert to json for the api
	lastDate, objects = api_util.turnGroupsIntoSections(groups, 1000)
	response['objects'] = objects
	response['next_start_date_time'] = lastDate
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

"""
	Utility method to find all nonNeighboredPhotos for the given user and location_point

	Returns a list of photos
"""
def getNonNeighboredPhotos(userId, lon, lat):
	# TODO(Derek):  Probably want to pull this out to some other place, maybe a param
	timeWithinHours = 3

	nowTime = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)

	timeLow = nowTime - datetime.timedelta(hours=timeWithinHours)

	photosCache = Photo.objects.filter(time_taken__gt=timeLow).exclude(user_id=userId).exclude(location_point=None).filter(user__product_id=1)

	nearbyPhotosData = geo_util.getNearbyPhotos(nowTime, lon, lat, photosCache, secondsWithin = timeWithinHours * 60 * 60)

	nearbyPhotos = list()
	for nearbyPhotoData in nearbyPhotosData:
		photo, timeDistance, geoDistance = nearbyPhotoData
		nearbyPhotos.append(photo)

	neighboredPhotos = getNeighboredPhotos(userId, timeLow)

	# We want to remove any photos that are already neighbored
	neighboredPhotosIds = Photo.getPhotosIds(neighboredPhotos)

	nonNeighboredPhotos = [item for item in nearbyPhotos if item.id not in neighboredPhotosIds]

	return nonNeighboredPhotos

"""
	the user would join if they took a picture at the given startTime (defaults to now)

	Searches for all photos of their friends within the time range and geo range but that don't have a
	  neighbor entry

	Used by the web view and the mobile client call

	returns (lastDate, objects) which should be handed back in the response as response['objects']
"""
def get_joinable_strands(request):
	response = dict({'result': True})

	timeWithinHours = 3

	form = GetJoinableStrandsForm(request.GET) 
	if form.is_valid():
		userId = form.cleaned_data['user_id']
		lon = form.cleaned_data['lon']
		lat = form.cleaned_data['lat']

		nonNeighboredPhotos = getNonNeighboredPhotos(userId, lon, lat)

		groups = getGroups([nonNeighboredPhotos])
		lastDate, objects = api_util.turnGroupsIntoSections(groups, 1000)

		response['objects'] = objects
		response['next_start_date_time'] = lastDate

		return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")
	else:
		response['result'] = False
		response['invalid_fields'] = api_util.formatErrors(form.errors)
		return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Returns back any new photos in the user's strands after the given date and time

	This looks at all the neighbor rows and see's if there's any ones with other people's photos
	taken after the startTime
"""
def get_new_photos(request):
	response = dict({'result': True})

	timeWithinHours = 3

	form = GetNewPhotosForm(request.GET)
	if form.is_valid():
		userId = form.cleaned_data['user_id']
		startTime = form.cleaned_data['start_date_time']

		photos = getNeighboredPhotos(userId, startTime)

		groups = getGroups([photos])
		lastDate, objects = api_util.turnGroupsIntoSections(groups, 1000)
		response['objects'] = objects
		response['next_start_date_time'] = lastDate

		return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")
	else:
		response['result'] = False
		response['invalid_fields'] = api_util.formatErrors(form.errors)
		return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Registers a user's current location (and only stores the last location)
"""
def update_user_location(request):
	response = dict({'result': True})
	form = UpdateUserLocationForm(request.GET)

	if (form.is_valid()):
		userId = form.cleaned_data['user_id']
		lon = form.cleaned_data['lon']
		lat = form.cleaned_data['lat']
		timestamp = form.cleaned_data['timestamp']

		if (not timestamp):
			timestamp = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)

		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			logger.error("Could not find user: %s " % (userId))
			response['error'] = 'userId not found'
			return HttpResponse(json.dumps(response), content_type="application/json")

		if ((not lon == 0) or (not lat == 0)):
			if ((user.last_location_timestamp and timestamp > user.last_location_timestamp) or not user.last_location_timestamp):
				user.last_location_point = fromstr("POINT(%s %s)" % (lon, lat))
				user.last_location_timestamp = timestamp
				user.save()
				logger.info("Location updated. %s: %s, %s" % (datetime.datetime.utcnow().replace(tzinfo=pytz.utc), userId, user.last_location_point))
			else:
				logger.info("Location NOT updated. Old Timestamp. %s: %s, %s" % (timestamp, userId, str((lon, lat))))
		else:
			logger.info("Location NOT updated. Lat/Lon Zero. %s: %s, %s" % (datetime.datetime.utcnow().replace(tzinfo=pytz.utc), userId, str((lon, lat))))

	else:
		response['result'] = False
		response['invalid_fields'] = api_util.formatErrors(form.errors)

	return HttpResponse(json.dumps(response), content_type="application/json")


"""
	Receives device tokens for APNS notifications
"""
def register_apns_token(request):
	response = dict({'result': True})
	form = RegisterAPNSTokenForm(request.GET)

	if (form.is_valid()):
		userId = form.cleaned_data['user_id']
		deviceToken = form.cleaned_data['device_token'].replace(' ', '').replace('<', '').replace('>', '')
		buildType = form.cleaned_data['build_type'] # not used but possible future use

		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			logger.error("Could not find user: %s " % (userId))
			return HttpResponse(json.dumps(response), content_type="application/json")

		# TODO (Aseem): Make this more efficient. Assume nothing!
		user.device_token = deviceToken
		apnsDev = APNService.objects.get(id=constants.IOS_NOTIFICATIONS_DEV_APNS_ID)
		apnsDerekDev = APNService.objects.get(id=constants.IOS_NOTIFICATIONS_DEREK_DEV_APNS_ID)
		apnsProd = APNService.objects.get(id=constants.IOS_NOTIFICATIONS_PROD_APNS_ID)

		devices = Device.objects.filter(token=deviceToken)

		if (len(devices) == 0):
			Device.objects.create(token=deviceToken, is_active=True, service=apnsDev)
			Device.objects.create(token=deviceToken, is_active=True, service=apnsDerekDev)
			Device.objects.create(token=deviceToken, is_active=True, service=apnsProd)
		else:
			for device in devices:
				if (not(device.token == deviceToken)):
					device.token = deviceToken
				if (not device.is_active):
					device.is_active = True
				device.save()
		user.save()
	else:
		response['result'] = False
		response['invalid_fields'] = api_util.formatErrors(form.errors)
	
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Returns a string that describes who is around.
	If people are around but haven't taken a photo, returns:  "5 friends are near you"
	If people are around and someone has taken a photo, returns:  "Henry & 4 other friends are near you"
	If more than one person is nearby, returns:  "Henry & Aseem & 1 other friend are near you"
"""
def get_nearby_friends_message(request):
	response = dict({'result': True})
	form = GetFriendsNearbyMessageForm(request.GET)

	timeWithinHours = 3
	
	if (form.is_valid()):
		userId = form.cleaned_data['user_id']
		lat = form.cleaned_data['lat']
		lon = form.cleaned_data['lon']

		timeWithin = datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(hours=timeWithinHours)

		# For now, search through all Users, when we have more, do something more efficent
		users = User.objects.exclude(id=userId).exclude(last_location_point=None).filter(product_id=1).filter(last_location_timestamp__gt=timeWithin)
		
		nearbyUsers = geo_util.getNearbyUsers(lon, lat, users, filterUserId=userId)
		photos = Photo.objects.filter(user_id__in=User.getIds(nearbyUsers)).filter(time_taken__gt=timeWithin)
		
		photoUsers = list()
		nonPhotoUsers = list()
		for user in nearbyUsers:
			hasPhoto = False
			for photo in photos:
				if photo.user_id == user.id:
					hasPhoto = True

			if hasPhoto:
				photoUsers.append(user)
			else:
				nonPhotoUsers.append(user)

		if len(nearbyUsers) == 0:
			message = ""
		elif len(photoUsers) == 0:
			if len(nearbyUsers) == 1:
				message = "There is 1 friend near you"
			else:
				message = "There are %s friends near you" % (len(nearbyUsers))
		elif len(photoUsers) > 0:
			names = list()
			for user in photoUsers:
				names.append(cleanName(user.display_name))
			names = set(names)
		
			if len(names) > 0:
				message = " & ".join(names) 

			if len(nonPhotoUsers) > 0:
				if len(nonPhotoUsers) == 1:
					message += " & 1 other friend"
				else:
					message += " & %s other friends" % len(nonPhotoUsers)

			if len(nearbyUsers) == 1:
				message += " is near you"
			else:
				message += " are near you"

		response['message'] = message
		response['result'] = True
	else:
		response['result'] = False
		response['invalid_fields'] = api_util.formatErrors(form.errors)
	
	return HttpResponse(json.dumps(response), content_type="application/json")


"""
	Sends a notification to the device/build_type based on the user_id
"""

def send_notifications_test(request):
	response = dict({'result': True})
	data = api_util.getRequestData(request)

	if data.has_key('user_id'):
		userId = data['user_id']
		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			return api_util.returnFailure(response, "user_id not found")
	else:
		return api_util.returnFailure(response, "Need user_id")

	if data.has_key('build_type'):
		buildType = int(data['build_type'])
	else:
		buildType = 0

	if data.has_key('msg'):
		msg = str(data['msg']) + ' ' + str(datetime.datetime.utcnow())
	else:
		msg = 'Strand test msg at ' + str(datetime.datetime.utcnow())
	
	customPayload = {'view': constants.NOTIFICATIONS_APP_VIEW_GALLERY}

	notifications_util.sendNotification(user, msg, constants.NOTIFICATIONS_NEW_PHOTO_ID, customPayload)

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

	form = SendSmsCodeForm(request.GET)
	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['phone_number'])

		accessCode = random.randrange(1000, 10000)

		msg = "Your Strand code is:  %s" % (accessCode)
	
		notifications_util.sendSMS(phoneNumber, msg)
		SmsAuth.objects.create(phone_number = phoneNumber, access_code = accessCode)
	else:
		response['result'] = False
		response['invalid_fields'] = api_util.formatErrors(form.errors)
	
	return HttpResponse(json.dumps(response), content_type="application/json")

"""
	Helper Method for auth_phone

	Strand specific code for creating a user.  If a user already exists, this will
	archive the old one by changing the phone number to an archive format (2352+15555555555)

	This also updates the SmsAuth object to point to this user

	Lastly, this creates the local directory

	TODO(Derek):  If we create users in more places, might want to move this
"""
def createUser(phoneNumber, displayName, smsAuth):
	try:
		user = User.objects.get(Q(phone_number=phoneNumber) & Q(product_id=1))
		
		# User exists, so need to archive
		# To do that, re-do the phone number, adding in an archive code
		archiveCode = random.randrange(1000, 10000)
		
		user.phone_number = "%s%s" %(archiveCode, phoneNumber)
		user.save()
	except User.DoesNotExist:
		pass

	# TODO(Derek): Make this more interesting when we add auth to the APIs
	authToken = random.randrange(10000, 10000000)

	user = User.objects.create(phone_number = phoneNumber, display_name = displayName, product_id = 1, auth_token = str(authToken))

	smsAuth.user_created = user
	smsAuth.save()

	# Create directory for photos
	# TODO(Derek): Might want to move to a more common location if more places that we create users
	try:
		userBasePath = user.getUserDataPath()
		os.stat(userBasePath)
	except:
		os.mkdir(userBasePath)
		os.chmod(userBasePath, 0775)

	return user

"""
	Call to authorize a phone with an sms code.  The SMS code should have been sent with send_sms_code
	above already.

	This then takes in the display_name and creates a user account
"""
@csrf_exempt
def auth_phone(request):
	response = dict({'result': True, 'errors': dict()})
	form = AuthPhoneForm(api_util.getRequestData(request))

	timeWithinMinutes = 10

	if (form.is_valid()):
		phoneNumber = str(form.cleaned_data['phone_number'])
		accessCode = form.cleaned_data['sms_access_code']
		displayName = form.cleaned_data['display_name']

		timeWithin = datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(minutes=timeWithinMinutes)

		smsAuth = SmsAuth.objects.filter(phone_number=phoneNumber, access_code=accessCode)

		if len(smsAuth) == 0 or len(smsAuth) > 1:
			response['result'] = False
			response['invalid_fields'] = api_util.formatErrors({'access_code': 'Invalid code'})
		elif smsAuth[0].user_created:
			response['result'] = False
			response['invalid_fields'] = api_util.formatErrors({'access_code': 'Code already used'})
		elif smsAuth[0].added < timeWithin:
			response['result'] = False
			response['invalid_fields'] = api_util.formatErrors({'access_code': 'Code expired'})
		else:
			user = createUser(phoneNumber, displayName, smsAuth[0])
			serializer = UserSerializer(user)
			response['user'] = serializer.data

	else:
		response['result'] = False
		response['invalid_fields'] = api_util.formatErrors(form.errors)

	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")
	
# TODO(Derek): move to a common loc, used in sendStrandNotifications
def cleanName(str):
	return str.split(' ')[0].split("'")[0]

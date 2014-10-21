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
from django.db import IntegrityError

from peanut.settings import constants

from common.models import Photo, User, SmsAuth, Strand, NotificationLog, ContactEntry, FriendConnection, StrandInvite, StrandNeighbor, Action
from common.serializers import UserSerializer

from common import api_util, cluster_util, serializers

from strand import geo_util, notifications_util, friends_util, strands_util
from strand.forms import GetJoinableStrandsForm, GetNewPhotosForm, RegisterAPNSTokenForm, UpdateUserLocationForm, GetFriendsNearbyMessageForm, SendSmsCodeForm, AuthPhoneForm, OnlyUserIdForm, StrandApiForm

from ios_notifications.models import APNService, Device, Notification

logger = logging.getLogger(__name__)

def getBestLocation(photo):
	if photo.twofishes_data:
		twoFishesData = json.loads(photo.twofishes_data)
		bestLocationName = None
		bestWoeType = 100
		if "interpretations" in twoFishesData:
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
	return None

def getActionsByPhotoIdCache(photoIds):
	actions = Action.objects.select_related().filter(photo_id__in=photoIds)
	actionsByPhotoId = dict()

	for action in actions:
		if action.photo_id not in actionsByPhotoId:
			actionsByPhotoId[action.photo_id] = list()
		actionsByPhotoId[action.photo_id].append(action)

	return actionsByPhotoId

def addActionsToClusters(clusters, actionsByPhotoIdCache):
	for cluster in clusters:
		for entry in cluster:
			if entry["photo"].id in actionsByPhotoIdCache:
				entry["actions"] = actionsByPhotoIdCache[entry["photo"].id]

	return clusters

def getBestLocationForPhotos(photos):
	# Grab title from the location_city of a photo...but find the first one that has
	#   a valid location_city
	bestLocation = None
	i = 0
	while (not bestLocation) and i < len(photos):
		bestLocation = getBestLocation(photos[i])
		i += 1

	return bestLocation

def getTitleForStrand(strand):
	photos = strand.photos.all()
	if len(photos) == 0:
		photos = strand.getPostPhotos()
		
	location = getBestLocationForPhotos(photos)

	dateStr = "%s %s" % (strand.first_photo_time.strftime("%b"), strand.first_photo_time.strftime("%d").lstrip('0'))

	if strand.first_photo_time.year != datetime.datetime.now().year:
		dateStr += ", " + strand.first_photo_time.strftime("%Y")

	title = dateStr

	if location:
		title = location + " on " + dateStr

	return title

def getLocationForStrand(strand):
	photos = strand.photos.all()
	if len(photos) == 0:
		photos = strand.getPostPhotos()
		
	location = getBestLocationForPhotos(photos)

	return location

"""
	Creates a cache which is a dictionary with the key being the strandId and the value
	a list of neighbor strands

	returns cache[strandId] = list(neighborStrand1, neighborStrand2...)
"""
def getStrandNeighborsCache(strands):
	strandIds = Strand.getIds(strands)

	strandNeighbors = StrandNeighbor.objects.select_related().filter(Q(strand_1__in=strandIds) | Q(strand_2__in=strandIds))

	strandNeighborsCache = dict()
	for strand in strands:
		for strandNeighbor in strandNeighbors:
			added = False
			if strand.id == strandNeighbor.strand_1_id:
				if strand.id not in strandNeighborsCache:
					strandNeighborsCache[strand.id] = list()
				if strandNeighbor.strand_2 not in strandNeighborsCache[strand.id]:
					strandNeighborsCache[strand.id].append(strandNeighbor.strand_2)
			elif strand.id == strandNeighbor.strand_2_id:
				if strand.id not in strandNeighborsCache:
					strandNeighborsCache[strand.id] = list()
				if strandNeighbor.strand_1 not in strandNeighborsCache[strand.id]:
					strandNeighborsCache[strand.id].append(strandNeighbor.strand_1)
					
	return strandNeighborsCache

"""
	Helper Method for auth_phone

	Strand specific code for creating a user.  If a user already exists, this will
	archive the old one by changing the phone number to an archive format (2352+15555555555)

	This also updates the SmsAuth object to point to this user

	Lastly, this creates the local directory

	TODO(Derek):  If we create users in more places, might want to move this
"""
def createStrandUser(phoneNumber, displayName, phoneId, smsAuth, returnIfExist = False):
	try:
		user = User.objects.get(Q(phone_number=phoneNumber) & Q(product_id=2))
		
		if returnIfExist or phoneNumber in constants.DEV_PHONE_NUMBERS:
			return user
		else:
			# User exists, so need to archive
			# To do that, re-do the phone number, adding in an archive code
			archiveCode = random.randrange(1000, 10000)
			
			user.phone_number = "%s%s" %(archiveCode, phoneNumber)
			user.save()
	except User.DoesNotExist:
		pass

	# TODO(Derek): Make this more interesting when we add auth to the APIs
	authToken = random.randrange(10000, 10000000)

	user = User.objects.create(phone_number = phoneNumber, display_name = displayName, phone_id = phoneId, product_id = 2, auth_token = str(authToken))

	if smsAuth:
		smsAuth.user_created = user
		smsAuth.save()

	logger.info("Created new user %s" % user)

	# Now pre-populate friends who this user was invited by
	invitedBy = ContactEntry.objects.filter(phone_number=phoneNumber).filter(contact_type="invited").exclude(skip=True)
	
	for invite in invitedBy:
		try:
			if user.id < invite.user.id:
				FriendConnection.objects.create(user_1=user, user_2=invite.user)
			else:
				FriendConnection.objects.create(user_1=invite.user, user_2=user)
			logger.debug("Created invite friend entry for user %s with user %s" % (user.id, invite.user.id))
		except IntegrityError:
			logger.warning("Tried to create friend connection between %s and %s but there was one already" % (user.id, invite.user.id))

	# Now fill in strand invites for this phone number
	strandInvites = StrandInvite.objects.filter(phone_number=user.phone_number).filter(invited_user__isnull=True).filter(accepted_user__isnull=True)
	for strandInvite in strandInvites:
		strandInvite.invited_user = user
	if len(strandInvites) > 0:
		StrandInvite.bulkUpdate(strandInvites, "invited_user_id")

		user.first_run_sync_timestamp = strandInvites[0].strand.first_photo_time

		logger.debug("Updated %s invites with user id %s and set first_run_sync_timestamp to %s" % (len(strandInvites), user.id, user.first_run_sync_timestamp))


	contacts = ContactEntry.objects.filter(phone_number = user.phone_number).exclude(user=user).exclude(skip=True).filter(user__product_id=2)
	friends = set([contact.user for contact in contacts])

	FriendConnection.addNewConnections(user, friends)

	# Create directory for photos
	# TODO(Derek): Might want to move to a more common location if more places that we create users
	try:
		userBasePath = user.getUserDataPath()
		os.stat(userBasePath)
	except:
		os.mkdir(userBasePath)
		os.chmod(userBasePath, 0775)

	return user


# ------------------------

# Deprecated
def getObjectsDataForStrands(user, strands, feedObjectType):
	friends = friends_util.getFriends(user.id)

	# list of list of photos
	groups = list()
	for strand in strands:
		strandId = strand.id
		photos = friends_util.filterStrandPhotosByFriends(user.id, friends, strand)
		
		metadata = {'type': feedObjectType, 'id': strandId, 'title': getTitleForStrand(strand), 'time_taken': strand.first_photo_time, 'actors': getActorsObjectData(list(strand.users.all()))}
		groupEntry = {'photos': photos, 'metadata': metadata}

		if len(photos) > 0:
			groups.append(groupEntry)

	if len(groups) > 0:
		# now sort groups by the time_taken of the first photo in each group
		groups = sorted(groups, key=lambda x: x['photos'][0].time_taken, reverse=True)

	formattedGroups = getFormattedGroups(groups)
		
	# Lastly, we turn our groups into sections which is the object we convert to json for the api
	objects = api_util.turnFormattedGroupsIntoFeedObjects(formattedGroups, 1000)
	return objects

def getActorsObjectData(users, includePhone = False, invitedUsers = None):
	if not isinstance(users, list):
		users = [users]

	userData = list()
	for user in users:
		entry = {'display_name': user.display_name, 'id': user.id}

		if includePhone:
			entry['phone_number'] = user.phone_number

		userData.append(entry)

	if invitedUsers:
		for user in invitedUsers:
			entry = {'display_name': user.display_name, 'id': user.id, 'invited': True}

			if includePhone:
				entry['phone_number'] = user.phone_number

			userData.append(entry)

	return userData


"""
	This turns a list of list of photos into groups that contain a title and cluster.

	We do all the photos at once so we can load up the sims cache once

	Takes in list of dicts::
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
def getFormattedGroups(groups):
	if len(groups) == 0:
		return []

	output = list()

	photoIds = list()
	for group in groups:
		for photo in group['photos']:
			photoIds.append(photo.id)

	# Fetch all the similarities at once so we can process in memory
	a = datetime.datetime.now()
	simCaches = cluster_util.getSimCaches(photoIds)
	
	# Do same with actions
	actionsByPhotoIdCache = getActionsByPhotoIdCache(photoIds)

	for group in groups:
		if len(group['photos']) == 0:
			continue

		clusters = cluster_util.getClustersFromPhotos(group['photos'], constants.DEFAULT_CLUSTER_THRESHOLD, 0, simCaches)
		clusters = addActionsToClusters(clusters, actionsByPhotoIdCache)
		
		location = getBestLocationForPhotos(group['photos'])
		if not location:
			location = "Location Unknown"

		metadata = group['metadata']
		metadata.update({'subtitle': location, 'location': location})
		
		output.append({'clusters': clusters, 'metadata': metadata})

	return output

def getObjectsDataForPhotos(user, photos, feedObjectType, strand = None):
	metadata = {'type': feedObjectType, 'title': ""}

	# We are looking at this variable as a temp fix so that a strand id is passed
	# to the client who can then hand it back.
	if strand:
		metadata['id'] = strand.id
		
	groups = [{'photos': photos, 'metadata': metadata}]

	formattedGroups = getFormattedGroups(groups)
		
	# Lastly, we turn our groups into sections which is the object we convert to json for the api
	objects = api_util.turnFormattedGroupsIntoFeedObjects(formattedGroups, 200)
	return objects

"""
	Returns back the objects data for private strands which includes neighbor_users.
	This gets the Strand Neighbors (two strands which are possible to strand together)
"""
def getObjectsDataForPrivateStrands(user, strands, feedObjectType):
	groups = list()


	friends = friends_util.getFriends(user.id)

	a = datetime.datetime.now()
	strandNeighborsCache = getStrandNeighborsCache(strands)

	# Create a dict of strand id to user list who might be interested in it
	strandToUserListCache = dict()
	for strand in strands:
		strandToUserListCache[strand.id] = strand.users.all()

	# We have all the users from the first fetch, now need to fetch all the neighbor's users
	existingStrandIds = Strand.getIds(strands)
	needToFetchStrandUsers = list()
	for strandId, strandNeighbors in strandNeighborsCache.iteritems():
		for strandNeighbor in strandNeighbors:
			if strandNeighbor.id not in existingStrandIds:
				needToFetchStrandUsers.append(strandNeighbor.id)
	
	# Add to the user list cache for each of the strand neighbors
	strandNeighbors = Strand.objects.prefetch_related('users').filter(id__in=needToFetchStrandUsers)
	for strandNeighbor in strandNeighbors:
		strandToUserListCache[strandNeighbor.id] = strandNeighbor.users.all()

	for strand in strands:
		strandId = strand.id
		photos = strand.photos.all() # .order_by("-time_taken")

		photos = sorted(photos, key=lambda x: x.time_taken, reverse=True)
		if len(photos) == 0:
			logger.error("in getObjectsDataForPrivateStrands found strand with no photos: %s" % (strand.id))
			continue
		
		interestedUsers = list()
		if strand.id in strandNeighborsCache:
			for neighborStrand in strandNeighborsCache[strand.id]:
				interestedUsers.extend(friends_util.filterUsersByFriends(user.id, friends, strandToUserListCache[neighborStrand.id]))

		interestedUsers = list(set(interestedUsers))

		if len(interestedUsers) > 0:
			title = "might like these photos"
		else:
			title = ""
		
		suggestible = strand.suggestible

		if suggestible and len(interestedUsers) == 0:
			suggestible = False

		if not getLocationForStrand(strand):
			interestedUsers = list()
			suggestible = False

		metadata = {'type': feedObjectType, 'id': strandId, 'title': title, 'time_taken': strand.first_photo_time, 'actors': getActorsObjectData(interestedUsers, True), 'suggestible': suggestible}
		entry = {'photos': photos, 'metadata': metadata}

		groups.append(entry)
	
	groups = sorted(groups, key=lambda x: x['photos'][0].time_taken, reverse=True)

	formattedGroups = getFormattedGroups(groups)
	print "private_strands-1d took %s ms" % ((datetime.datetime.now()-a).microseconds / 1000 + (datetime.datetime.now()-a).seconds * 1000)
	# Lastly, we turn our groups into sections which is the object we convert to json for the api
	objects = api_util.turnFormattedGroupsIntoFeedObjects(formattedGroups, 200)
	print "private_strands-1e took %s ms" % ((datetime.datetime.now()-a).microseconds / 1000 + (datetime.datetime.now()-a).seconds * 1000)
	return objects


def getPrivateStrandSuggestionsForSharedStrand(user, strand):
	# Look above and below 10x the number of minutes to strand
	timeHigh = strand.last_photo_time + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING*5)
	timeLow = strand.first_photo_time - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING*5)

	# Get all the unshared strands for the given user that are close to the given strand
	privateStrands = Strand.objects.select_related().filter(users__in=[user]).filter(private=True).filter(last_photo_time__lt=timeHigh).filter(first_photo_time__gt=timeLow)
	
	strandsThatMatch = list()
	for privateStrand in privateStrands:
		for photo in privateStrand.photos.all():
			if strands_util.photoBelongsInStrand(photo, strand) and privateStrand not in strandsThatMatch:
				strandsThatMatch.append(privateStrand)

	return strandsThatMatch
	
def getObjectsDataForPost(postAction):
	metadata = {'type': constants.FEED_OBJECT_TYPE_STRAND_POST, 'id': postAction.id, 'time_stamp': postAction.added, 'actors': getActorsObjectData(postAction.user)}
	photos = postAction.photos.all().order_by('time_taken')
	metadata['title'] = "added %s photos" % len(photos)

	groupEntry = {'photos': photos, 'metadata': metadata}

	formattedGroups = getFormattedGroups([groupEntry])
		
	# Lastly, we turn our groups into sections which is the object we convert to json for the api
	objects = api_util.turnFormattedGroupsIntoFeedObjects(formattedGroups, 200)
	return objects

def getObjectsDataForStrand(strand, user):
	response = dict()

	postActions = strand.action_set.filter(Q(action_type=constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND) | Q(action_type=constants.ACTION_TYPE_CREATE_STRAND))

	if len(postActions) == 0:
		logger.error("in getObjectsDataForStrand found no actions for strand %s and user %s" % (strand.id, user.id))
		recentTimeStamp = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	else:
		recentTimeStamp = sorted(postActions, key=lambda x:x.added, reverse=True)[0].added
		
	users = strand.users.all()

	invitedUsers = list()
	for invite in strand.strandinvite_set.select_related().filter(accepted_user__isnull=True).exclude(invited_user=user):
		if invite.invited_user and invite.invited_user not in users and invite.invited_user not in invitedUsers:
			invitedUsers.append(invite.invited_user)
		elif not invite.invited_user:
			contactEntries = ContactEntry.objects.filter(user=user, phone_number=invite.phone_number, skip=False)
			name = ""
			for entry in contactEntries:
				if name == "":
					name = entry.name.split(" ")[0]

			invitedUsers.append(User(id=0, display_name=name))
	
	response = {'type': constants.FEED_OBJECT_TYPE_STRAND_POSTS, 'title': getTitleForStrand(strand), 'id': strand.id, 'actors': getActorsObjectData(list(strand.users.all()), invitedUsers=invitedUsers), 'time_taken': strand.first_photo_time, 'time_stamp': recentTimeStamp, 'location': getLocationForStrand(strand)}
	response['objects'] = list()
	for post in postActions:
		response['objects'].extend(getObjectsDataForPost(post))
	return response

def getInviteObjectsDataForUser(user):
	responseObjects = list()

	strandInvites = StrandInvite.objects.select_related().filter(invited_user=user).exclude(skip=True).filter(accepted_user__isnull=True)

	for strandInvite in strandInvites:
		inviteIsReady = True
		thumbsLoaded = True
		invitePhotos = strandInvite.strand.photos.all()
		
		# Go through all photos and see if there's any that don't belong to this user
		#  and don't have a thumb.  If a user just created an invite this should be fine
		for photo in invitePhotos:
			if photo.user_id != user.id and not photo.thumb_filename:
				thumbsLoaded = False

		if thumbsLoaded:
			if user.first_run_sync_count == 0 or user.first_run_sync_complete:
				inviteIsReady = True
			else:
				inviteIsReady = False

			title = "shared %s photos with you" % strandInvite.strand.photos.count()
			entry = {'type': constants.FEED_OBJECT_TYPE_INVITE_STRAND, 'id': strandInvite.id, 'title': title, 'actors': getActorsObjectData(list(strandInvite.strand.users.all())), 'time_stamp': strandInvite.added}
			entry['ready'] = inviteIsReady
			entry['objects'] = list()
			entry['objects'].append(getObjectsDataForStrand(strandInvite.strand, user))

			privateStrands = getPrivateStrandSuggestionsForSharedStrand(user, strandInvite.strand)

			suggestionsEntry = {'type': constants.FEED_OBJECT_TYPE_SUGGESTED_PHOTOS}
			suggestionsEntry['objects'] = getObjectsDataForPrivateStrands(user, privateStrands, constants.FEED_OBJECT_TYPE_STRAND)

			entry['objects'].append(suggestionsEntry)

			responseObjects.append(entry)
	return responseObjects


#####################################################################################
#################################  EXTERNAL METHODS  ################################
#####################################################################################


# ----------------------- FEED ENDPOINTS --------------------

"""
	Return the Duffy JSON for the strands a user has that are private and unshared
"""
def private_strands(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']

		a = datetime.datetime.now()
		
		strands = list(Strand.objects.prefetch_related('photos', 'users').filter(users__in=[user]).filter(private=True))

		b = datetime.datetime.now()

		print "private_strands-1 took %s ms" % ((b-a).microseconds / 1000 + (b-a).seconds * 1000)

		response['objects'] = getObjectsDataForPrivateStrands(user, strands, constants.FEED_OBJECT_TYPE_STRAND)
		c = datetime.datetime.now()

		print "private_strands-2 took %s ms" % ((c-b).microseconds / 1000 + (c-b).seconds * 1000)

		print "private_strands-total took %s ms" % ((c-a).microseconds / 1000 + (c-a).seconds * 1000)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")



"""
	Returns back the invites and strands a user has
"""
def strand_inbox(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		responseObjects = list()

		# First throw in invite objects
		responseObjects.extend(getInviteObjectsDataForUser(user))
		
		# Next throw in the list of existing Strands
		strands = set(Strand.objects.select_related().filter(users__in=[user]).filter(private=False))

		#nonInviteStrandObjects = list()
		for strand in strands:
			responseObjects.append(getObjectsDataForStrand(strand, user))

		# sorting by last action on the strand
		responseObjects = sorted(responseObjects, key=lambda x: x['time_stamp'], reverse=True)
		#responseObjects.extend(nonInviteStrandObjects)

		# Add in the list of all friends at the end
		entry = {'type': constants.FEED_OBJECT_TYPE_FRIENDS_LIST, 'actors': getActorsObjectData(friends_util.getFriends(user.id), True)}
		responseObjects.append(entry)

		response['objects'] = responseObjects
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")



# ---------------------------------------------------------------

# Soon to be deprecated
def invited_strands(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		response['objects'] = getInviteObjectsDataForUser(user)
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

			msg = "Your Strand code is:  %s" % (accessCode)
	
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
				user = createStrandUser(phoneNumber, displayName, phoneId, smsAuth[0], returnIfExist = True)
				serializer = UserSerializer(user)
				response['user'] = serializer.data
		else:
			if accessCode == 2345:
				user = createStrandUser(phoneNumber, displayName, phoneId, None, returnIfExist = True)
				serializer = UserSerializer(user)
				response['user'] = serializer.data
			else:
				return HttpResponse(json.dumps({'access_code': 'Invalid code'}), content_type="application/json", status=400)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")



def nothing(request):
	return HttpResponse(json.dumps(dict()), content_type="application/json")


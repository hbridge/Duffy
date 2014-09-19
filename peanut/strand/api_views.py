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
from common.serializers import UserSerializer, PhotoForApiSerializer

from common import api_util, cluster_util

from strand import geo_util, notifications_util, friends_util, strands_util
from strand.forms import GetJoinableStrandsForm, GetNewPhotosForm, RegisterAPNSTokenForm, UpdateUserLocationForm, GetFriendsNearbyMessageForm, SendSmsCodeForm, AuthPhoneForm, OnlyUserIdForm, StrandApiForm, SuggestedUnsharedPhotosForm

from ios_notifications.models import APNService, Device, Notification

logger = logging.getLogger(__name__)

# TODO(Derek): move to a common loc, used in sendStrandNotifications
def cleanName(str):
	return str.split(' ')[0].split("'")[0]

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
		
	location = getBestLocationForPhotos(photos)

	dateStr = "%s %s" % (strand.first_photo_time.strftime("%b"), strand.first_photo_time.strftime("%d").lstrip('0'))

	if strand.first_photo_time.year != datetime.datetime.now().year:
		dateStr += ", " + strand.first_photo_time.strftime("%Y")

	title = dateStr

	if location:
		title += " in " + location

	return title

def getActorsObjectData(actors, includePhone = False):
	if not isinstance(actors, list):
		actors = [actors]

	userData = list()
	for user in actors:
		entry = {'display_name': user.display_name, 'id': user.id}

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
		user = User.objects.get(Q(phone_number=phoneNumber) & Q(product_id=1))
		
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

	user = User.objects.create(phone_number = phoneNumber, display_name = displayName, phone_id = phoneId, product_id = 1, auth_token = str(authToken))

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
		logger.debug("Updated %s invites with user id %s" % (len(strandInvites), user.id))
	
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
	Creates a cache which is a dictionary with the key being the strandId and the value
	a list of neighbor strands

	returns cache[strandId] = list(neighborStrand1, neighborStrand2...)
"""
def getStrandNeighborsCache(strands):
	strandIds = Strand.getIds(strands)

	strandNeighbors = StrandNeighbor.objects.filter(Q(strand_1__in=strandIds) | Q(strand_2__in=strandIds))

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
	
def getObjectsDataForPhotos(user, photos, feedObjectType):
	metadata = {'type': feedObjectType, 'title': ""}
	groups = [{'photos': photos, 'metadata': metadata}]

	formattedGroups = getFormattedGroups(groups)
		
	# Lastly, we turn our groups into sections which is the object we convert to json for the api
	objects = api_util.turnFormattedGroupsIntoFeedObjects(formattedGroups, 1000)
	return objects

def getObjectsDataForStrands(user, strands, feedObjectType):
	friendsData = friends_util.getFriendsData(user.id)

	# list of list of photos
	groups = list()
	for strand in strands:
		strandId = strand.id
		photos = friends_util.filterStrandPhotosByFriends(user.id, friendsData, strand)
		
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

"""
	Returns back the objects data for private strands which includes neighbor_users.
	This gets the Strand Neighbors (two strands which are possible to strand together)
"""
def getObjectsDataForPrivateStrands(user, strands, feedObjectType):
	groups = list()
	
	strandNeighborsCache = getStrandNeighborsCache(strands)
	for strand in strands:
		strandId = strand.id
		photos = strand.photos.all().order_by("-time_taken")
		
		interestedUsers = list()
		if strand.id in strandNeighborsCache:
			for neighborStrand in strandNeighborsCache[strand.id]:
				interestedUsers.extend(neighborStrand.users.all())

		interestedUsers = list(set(interestedUsers))

		if len(interestedUsers) > 0:
			title = "might like these photos"
		else:
			title = ""
			
		metadata = {'type': feedObjectType, 'id': strandId, 'title': title, 'time_taken': strand.first_photo_time, 'actors': getActorsObjectData(interestedUsers, True)}
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

"""
def addPhotosActionExists(user, strand, actions):
	for action in actions:
		if action.action_type == ACTION_TYPE_ADD_PHOTOS_TO_STRAND and action.user.id == user.id and action.strand.id == strand.id:
			return True
	return False
"""

def getObjectsDataForActions(user):
	objectResponse = []
	#strands = Strand.objects.filter(users__in=[user]).filter(shared=True)

	actions = Action.objects.filter(Q(photo__user_id=user.id) | Q(user=user) | Q(strand__users__in=[user])).order_by("-added")[:20]
	
	actions = set(actions)
	for action in actions:
		objects = None
		if action.action_type == constants.ACTION_TYPE_FAVORITE:
			if action.user.id == user.id and action.photo.user.id == user.id:
				title = "liked your photo from %s" % (getTitleForStrand(action.strand))
			elif action.user.id == user.id:
				title = "liked %s's photo from %s" % (action.photo.user.display_name, getTitleForStrand(action.strand))
			elif action.photo.user.id == user.id:
				title = "liked your photo from %s" % (getTitleForStrand(action.strand))
			else:
				title = "Unknown"
				
			entry = {'type': constants.FEED_OBJECT_TYPE_LIKE_ACTION, 'title': title, 'actors': getActorsObjectData(action.user), 'time_stamp': action.added, 'id': action.id}

			photoData = PhotoForApiSerializer(action.photo).data
			photoData['type'] = "photo"
			entry['objects'] = [photoData]
			objectResponse.append(entry)
			continue

		# Show this for yourself
		if action.action_type == constants.ACTION_TYPE_CREATE_STRAND:
			title = "%s photos from %s" % (action.photos.count(), getTitleForStrand(action.strand))
			feedType = constants.FEED_OBJECT_TYPE_STRAND_POST
			objects = getObjectsDataForStrands(user, [action.strand], constants.FEED_OBJECT_TYPE_STRAND)

		# Don't show added or joined for yourself, only other people
		if action.user.id != user.id:
			if action.action_type == constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND:
				title = "%s photos from %s" % (action.photos.count(), getTitleForStrand(action.strand))
				feedType = constants.FEED_OBJECT_TYPE_STRAND_POST
				objects = getObjectsDataForPhotos(user, action.photos.all(), constants.FEED_OBJECT_TYPE_STRAND)
				objects[0]['title'] = getTitleForStrand(action.strand)

			"""
			# only show joined if there isn't also an "add photos"
			elif action.action_type == constants.ACTION_TYPE_JOIN_STRAND and not addPhotosActionExists(user, action.strand, actions):
				title = "joined a Strand"
				feedType = constants.FEED_OBJECT_TYPE_STRAND_JOIN
				objects = getObjectsDataForStrands(user, [action.strand], constants.FEED_OBJECT_TYPE_STRAND)
			"""
		
		if objects:
			entry = {'type': feedType, 'title': title, 'actors': getActorsObjectData(action.user), 'time_stamp': action.added, 'id': action.id, 'objects': objects}
			objectResponse.append(entry)

	return objectResponse

def getPhotosSuggestionsForStrand(user, strand):
	timeHigh = strand.last_photo_time + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)
	timeLow = strand.first_photo_time - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)

	# Get all the unshared strands for the given user that are close to the given strand
	unsharedStrands = Strand.objects.select_related().filter(users__in=[user]).filter(shared=False).filter(last_photo_time__lt=timeHigh).filter(first_photo_time__gt=timeLow)
	
	unsharedPhotos = list()
	for unsharedStrand in unsharedStrands:
		unsharedPhotos.extend(unsharedStrand.photos.all())
	unsharedPhotos = set(unsharedPhotos)

	matchingPhotos = list()
	if len(unsharedPhotos) > 0:
		# For each photo, see if it would do well in a strand from the cache
		for photo in unsharedPhotos:
			if strands_util.photoBelongsInStrand(photo, strand):
				matchingPhotos.append(photo)

		matchingPhotos = sorted(matchingPhotos, key=lambda x: x.time_taken, reverse=True)

	return matchingPhotos
	
def getInviteObjectsDataForUser(user):
	responseObjects = list()

	strandInvites = StrandInvite.objects.select_related().filter(invited_user=user).exclude(skip=True).filter(accepted_user__isnull=True)

	for strandInvite in strandInvites:
		shouldShowInvite = True
		
		# Go through all photos and see if there's any that don't belong to this user
		#  and don't have a thumb.  If a user just created an invite this should be fine
		for photo in strandInvite.strand.photos.all():
			if photo.user_id != user.id and not photo.thumb_filename:
				shouldShowInvite = False

		if shouldShowInvite:
			entry = {'type': constants.FEED_OBJECT_TYPE_INVITE_STRAND, 'id': strandInvite.id, 'title': "invited you to a Strand", 'actors': getActorsObjectData(strandInvite.user)}
			entry['objects'] = getObjectsDataForStrands(user, [strandInvite.strand], constants.FEED_OBJECT_TYPE_STRAND)

			"""

			TODO (Derek): Figure out a way to use neighbors.
				Can't right now because with newly created strands, those entries aren't written


			# Find this user's private strands which are neighbors to the invited strand
			strandNeighborsCache = getStrandNeighborsCache([strandInvite.strand])
			
			privateNeighborStrands = list()
			# If we found some neighbors to this strand, add them in as suggestion objects
			if strandInvite.strand.id in strandNeighborsCache:
				for strand in strandNeighborsCache[strandInvite.strand.id]:
					if strand.shared == False and user in strand.users.all():
						privateNeighborStrands.append(strand)
				suggestionsEntries = getObjectsDataForStrands(user, privateNeighborStrands, constants.FEED_OBJECT_TYPE_SUGGESTED_PHOTOS)

				entry['objects'].extend(suggestionsEntries)
			"""
			photos = getPhotosSuggestionsForStrand(user, strandInvite.strand)
			suggestionsEntries = getObjectsDataForPhotos(user, photos, constants.FEED_OBJECT_TYPE_SUGGESTED_PHOTOS)

			entry['objects'].extend(suggestionsEntries)

			responseObjects.append(entry)
	return responseObjects
		
#####################################################################################
#################################  EXTERNAL METHODS  ################################
#####################################################################################


# ----------------------- FEED ENDPOINTS --------------------

def invited_strands(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		response['objects'] = getInviteObjectsDataForUser(user)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

"""
	Return the Duffy JSON for the strands a user has that are private and unshared

	This uses the Strand objects instead of neighbors
"""
def unshared_strands(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		
		strands = set(Strand.objects.select_related().filter(users__in=[user]).filter(shared=False))

		response['objects'] = getObjectsDataForPrivateStrands(user, strands, constants.FEED_OBJECT_TYPE_STRAND)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

"""
	Return the Duffy JSON for "private" photos for a user that are a good match for the given strand

	TODO(Derek):  Remove this
"""
def suggested_unshared_photos(request):
	response = dict({'result': True})

	form = SuggestedUnsharedPhotosForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']

		# This is the strand we're looking in the users's private photos to see if there's any good matches
		strand = form.cleaned_data['strand']

		photos = getPhotosSuggestionsForStrand(user, strand)
		suggestionsEntries = getObjectsDataForPhotos(user, photos, constants.FEED_OBJECT_TYPE_SUGGESTED_PHOTOS)

		response['objects'] = suggestionsEntries
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")


"""
	Return the Duffy JSON for the photo feed.

	This uses the Strand objects instead of neighbors
"""
def strand_feed(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		strands = Strand.objects.select_related().filter(users__in=[user]).filter(shared=True)
		objectData = getObjectsDataForStrands(user, strands, constants.FEED_OBJECT_TYPE_STRAND)

		response['objects'] = objectData
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

def strand_activity(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		responseObjects = list()

		# First throw in invite objects
		inviteObjects = getInviteObjectsDataForUser(user)
		responseObjects.extend(inviteObjects)
		
		# Created Strands
		# TODO(Derek): remove hack
		# This is a hack right now that looks at strand invites and assumes that if you did the invite,
		#   you created the strand
		"""
		sentStrandInvites = StrandInvite.objects.select_related().filter(user=user).exclude(skip=True)
		createdStrandList = set([x.strand for x in sentStrandInvites])
		
		createdStrandObjects = list()
		for strand in createdStrandList:
			entry = {'type': constants.FEED_OBJECT_TYPE_STRAND_POST, 'title': "started a Strand", 'actors': getActorsObjectData(user), 'time_stamp': strand.added}
			entry['objects'] = getObjectsDataForStrands(user, [strand], constants.FEED_OBJECT_TYPE_STRAND)

			createdStrandObjects.append(entry)
		"""
		actionObjects = getObjectsDataForActions(user)

		# Grab sent created strands and action data, then sort.  We put invites at the top
		afterInviteFeedObjects = list()
		afterInviteFeedObjects.extend(actionObjects)
		#afterInviteFeedObjects.extend(createdStrandObjects)

		afterInviteFeedObjects = sorted(afterInviteFeedObjects, key=lambda x: x['time_stamp'], reverse=True)

		responseObjects.extend(afterInviteFeedObjects)

		response['objects'] = responseObjects
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")



"""
	the user would join if they took a picture at the given startTime (defaults to now)

	Searches for all photos of their friends within the time range and geo range but that don't have a
	  neighbor entry

	Used by the web view and the mobile client call

	returns (lastDate, objects) which should be handed back in the response as response['objects']
"""
def get_joinable_strands(request):
	response = dict({'result': True})

	nowTime = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	timeLow = nowTime - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)

	form = GetJoinableStrandsForm(api_util.getRequestData(request)) 
	if form.is_valid():
		user = form.cleaned_data['user']
		lon = form.cleaned_data['lon']
		lat = form.cleaned_data['lat']

		friendsData = friends_util.getFriendsData(user.id)
		strands = Strand.objects.select_related().filter(last_photo_time__gt=timeLow)

		joinableStrandPhotos = strands_util.getJoinableStrandPhotos(user.id, lon, lat, strands, friendsData)
		
		response['objects'] = getObjectsDataForPhotos(user, joinableStrandPhotos, constants.FEED_OBJECT_TYPE_STRAND)
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)
	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

"""
	Returns back any new photos in the user's strands after the given date and time
"""
def get_new_photos(request):
	response = dict({'result': True})

	form = GetNewPhotosForm(api_util.getRequestData(request))
	if form.is_valid():
		user = form.cleaned_data['user']
		startTime = form.cleaned_data['start_date_time']
		photoList = list()

		strands = Strand.objects.filter(last_photo_time__gt=startTime).filter(users=user.id).filter(shared=True)
		
		for strand in strands:
			for photo in strand.photos.filter(time_taken__gt=startTime):
				if photo.user_id != user.id:
					photoList.append(photo)

		photoList = removeDups(photoList, lambda x: x.id)

		response['objects'] = getObjectsDataForPhotos(user, photoList, constants.FEED_OBJECT_TYPE_STRAND)
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
		last_photo_timestamp = form.cleaned_data['last_photo_timestamp']
		
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		
		if ((not lon == 0) or (not lat == 0)):
			if ((user.last_location_timestamp and timestamp and timestamp > user.last_location_timestamp) or not user.last_location_timestamp):
				user.last_location_point = fromstr("POINT(%s %s)" % (lon, lat))

				if timestamp:
					user.last_location_timestamp = timestamp
				else:
					user.last_location_timestamp = now

				user.last_location_accuracy = accuracy

				if last_photo_timestamp:
					user.last_photo_timestamp = last_photo_timestamp
					logger.info("Last Photo: %s, %s" % (user.id, last_photo_timestamp))
				
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
	Returns a string that describes who is around.
	If people are around but haven't taken a photo, returns:  "5 friends are near you"
	If people are around and someone has taken a photo, returns:  "Henry & 4 other friends are near you"
	If more than one person is nearby, returns:  "Henry & Aseem & 1 other friend are near you"
"""
def get_nearby_friends_message(request):
	response = dict({'result': True})
	form = GetFriendsNearbyMessageForm(api_util.getRequestData(request))

	timeWithinHours = 3
	
	if (form.is_valid()):
		user = form.cleaned_data['user']
		lat = form.cleaned_data['lat']
		lon = form.cleaned_data['lon']

		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		timeWithin = now - datetime.timedelta(hours=timeWithinHours)

		friendsData = friends_util.getFriendsData(user.id)
		
		# For now, search through all Users, when we have more, do something more efficent
		users = User.objects.exclude(id=user.id).exclude(last_location_point=None).filter(product_id=1).filter(last_location_timestamp__gt=timeWithin)
		users = friends_util.filterUsersByFriends(user.id, friendsData, users)

		nearbyUsers = geo_util.getNearbyUsers(lon, lat, users, filterUserId=user.id)

		photos = Photo.objects.filter(user_id__in=User.getIds(nearbyUsers)).filter(time_taken__gt=timeWithin)
		
		nearbyPhotosData = geo_util.getNearbyPhotos(now, lon, lat, photos, filterUserId=user.id)

		photoUsers = list()
		nonPhotoUsers = nearbyUsers
		
		for user in users:
			hasPhoto = False
			for nearbyPhotoData in nearbyPhotosData:
				photo, timeDistance, geoDistance = nearbyPhotoData
				if photo.user_id == user.id:
					hasPhoto = True

			if hasPhoto:
				photoUsers.append(user)

				# Remove this user from the nonPhotos list since we've found a photo
				nonPhotoUsers = filter(lambda a: a.id != user.id, nonPhotoUsers)

		if len(photoUsers) == 0 and len(nonPhotoUsers) == 0:
			message = ""
			expMessage = "No friends are near you."
		elif len(photoUsers) == 0:
			if len(nonPhotoUsers) == 1:
				message = "1 friend will see this photo"
				expMessage = "1 friend near you hasn't taken a photo yet. Take a photo to share with them."
			else:
				message = "%s friends will see this photo" % (len(nonPhotoUsers))
				expMessage = "%s friends near you haven't taken a photo yet. Take a photo to share with them." % (len(nearbyUsers))
		elif len(photoUsers) > 0:
			names = list()
			for user in photoUsers:
				names.append(cleanName(user.display_name))
		
			if len(nonPhotoUsers) == 0:
				if len(names) <= 2:
					message = " & ".join(names)
				else:
					numNames = len(names)
					message = ", ".join(names[:numNames-2])
					message += " & %s" % (names[numNames-1])
				expMessage = message + " took a photo near you."
			else:
				message = ", ".join(names)
				expMessage = message + " took a photo near you."

				if len(nonPhotoUsers) == 1:
					message += " & 1 friend"
					expMessage += " 1 other friend near you hasn't taken a photo yet."
				else:
					message += " & %s friends" % len(nonPhotoUsers)
					expMessage += " %s other friends near you haven't taken a photo yet." % len (nonPhotoUsers)

			message += " will see this photo"

		response['message'] = message
		response['expanded_message'] = expMessage
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

	if data.has_key('pid'):
		customPayload['pid'] = int(data['pid'])

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

"""
def get_invite_message(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
	
		if ('enterprise' in form.cleaned_data['build_id'].lower()):
			inviteLink = constants.INVITE_LINK_ENTERPRISE
		else:
			inviteLink = constants.INVITE_LINK_APP_STORE

		response['invite_message'] = "Try this app so we can share photos when we hang out: "  + inviteLink + "."
		response['invites_remaining'] = user.invites_remaining
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")

def get_notifications(request):
	response = dict({'result': True})

	form = OnlyUserIdForm(api_util.getRequestData(request))

	if (form.is_valid()):
		user = form.cleaned_data['user']
		response['notifications'] = list()

		photoActions = PhotoAction.objects.filter(photo__user_id=user.id).order_by("-added")[:20]

		for photoAction in photoActions:
			if photoAction.user_id != user.id:
				metadataMsg = 'liked your photo'
				metadata = {'photo_id': photoAction.photo_id,
							'action_text': metadataMsg,
							'actor_user': photoAction.user_id,
							'actor_display_name':  photoAction.user.display_name,
							'photo_thumb_path': photoAction.photo.getThumbUrlImagePath(),
							'time': photoAction.added}
				response['notifications'].append(metadata)
		
	else:
		return HttpResponse(json.dumps(form.errors), content_type="application/json", status=400)

	return HttpResponse(json.dumps(response, cls=api_util.DuffyJsonEncoder), content_type="application/json")
"""


import logging
import datetime
import pytz

from django.db.models import Q
from django.conf import settings

from strand import geo_util, friends_util, strands_util
from common.models import Photo, Strand, StrandNeighbor, Action, User, ShareInstance

from common import stats_util, cluster_util, api_util, serializers

from peanut.settings import constants

logger = logging.getLogger(__name__)


# Fetch strands we want to find neighbors on
# Fetch neighbors rows that match strands and friends
# Fetch neighbor strands and neighbor users
# Filter out eval'd photos
# Format private strand with interested users
def getFeedObjectsForSwaps(user):
	responseObjects = list()
	strandIdsAlreadyIncluded = list()

	friends = friends_util.getFriends(user.id)

	# on dev, we want a larger window to test in simulators
	if '555555' in str(user.phone_number):
		days = 365
	else:
		days = 30

	timeCutoff = datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(days=days)
	recentStrands = Strand.objects.filter(user=user).filter(private=True).filter(suggestible=True).filter(first_photo_time__gt=timeCutoff).order_by('-first_photo_time')
	stats_util.printStats("swaps-recent-cache")
	
	interestedUsersByStrandId, matchReasonsByStrandId, strands = getInterestedUsersForStrands(user, recentStrands, True, friends)
	stats_util.printStats("swaps-b")
	
	actionsByPhotoId = getActionsByPhotoIdForStrands(user, strands)
	stats_util.printStats("swaps-d")
		
	for strand in strands:
		strandObjectData = serializers.objectDataForPrivateStrand(user, strand, friends, False, "friend-location", interestedUsersByStrandId, matchReasonsByStrandId, actionsByPhotoId)
		if strandObjectData:
			strandIdsAlreadyIncluded.add(strand.id)
			responseObjects.append(strandObjectData)

	responseObjects = sorted(responseObjects, key=lambda x: x['time_taken'], reverse=True)

	if len(responseObjects) < 3:
		lastWeekResponseObjects = list()
		
		timeCutoff = datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(days=7)
		mostRecentStrandIds = list()

		# grab the strands that we fetched before but that are within our time cutoff
		# and that we didn't add already
		for strand in recentStrands:
			if strand.first_photo_time > timeCutoff and strand.id not in strandIdsAlreadyIncluded:
				mostRecentStrandIds.append(strand.id)

		strands = Strand.objects.prefetch_related('photos').filter(id__in=mostRecentStrandIds)
		actionsByPhotoId = getActionsByPhotoIdForStrands(user, strands)

		for strand in strands:
			strandObjectData = serializers.objectDataForPrivateStrand(user, strand, friends, False, "recent-last week", dict(), dict(), actionsByPhotoId)
			if strandObjectData:
				lastWeekResponseObjects.append(strandObjectData)

		lastWeekResponseObjects = sorted(lastWeekResponseObjects, key=lambda x: x['time_taken'], reverse=True)
	
		responseObjects.extend(lastWeekResponseObjects)

	return responseObjects

def getFeedObjectsForPrivateStrands(user):
	responseObjects = list()

	friends = friends_util.getFriends(user.id)

	allPrivateStrands = Strand.objects.prefetch_related('photos').filter(user=user).filter(private=True).filter(suggestible=True).order_by('-first_photo_time')
	for strand in allPrivateStrands:
		for photo in strand.photos.all():
			photo.user = user
	
	stats_util.printStats("private-all-cache")
	
	interestedUsersByStrandId, matchReasonsByStrandId, strands = getInterestedUsersForStrands(user, allPrivateStrands, True, friends)
	stats_util.printStats("private-b")
		
	for strand in allPrivateStrands:
		strandObjectData = serializers.objectDataForPrivateStrand(user, strand, friends, True, "", interestedUsersByStrandId, matchReasonsByStrandId, dict())
		if strandObjectData:
			responseObjects.append(strandObjectData)

	return responseObjects

def getActionsByPhotoIdForStrands(user, strands):
	photoIds = list()
	for strand in strands:
		photoIds.extend(Photo.getIds(strand.photos.all()))

	evalActions = Action.objects.filter(Q(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED) & Q(user=user) & Q(photo_id__in=photoIds))
	actionsByPhotoId = dict()
	for action in evalActions:
		if action.photo_id not in actionsByPhotoId:
			actionsByPhotoId[action.photo_id] = list()
		actionsByPhotoId[action.photo_id].append(action)

	return actionsByPhotoId

# Takes in a list of strands and finds all the users that are interested in them.
# Returns back a dict of users by strand id, along with the strands prefilled
def getInterestedUsersForStrands(user, strands, locationRequired, friends):
	interestedUsersByStrandId = dict()
	matchReasonsByStrandId = dict()

	# TODO(Derek): If we want to speed up this call, then we could have the neighbor row
	# keep track of the start of the strand and only fetch neighbors 
	neighborStrandsByStrandId, neighborUsersByStrandId = getStrandNeighborsCache(strands, friends)
	stats_util.printStats("swaps-neighbors-cache")

	strandIds = neighborStrandsByStrandId.keys()
	strandIds.extend(neighborUsersByStrandId.keys())

	strandsWithNeighbors = Strand.objects.prefetch_related('photos').filter(id__in=strandIds)
	
	# The prefetch for 'user' took a while here so just do it manually
	for strand in strandsWithNeighbors:
		for photo in strand.photos.all():
			photo.user = user

	for strand in strandsWithNeighbors:
		matchReasons = dict()
		interestedUsers = list()
		if strand.id in neighborStrandsByStrandId:
			for neighborStrand in neighborStrandsByStrandId[strand.id]:
				if neighborStrand.location_point and strand.location_point and strands_util.strandsShouldBeNeighbors(strand, neighborStrand, distanceLimit = constants.DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING, locationRequired = locationRequired):
					val, reason = strands_util.strandsShouldBeNeighbors(strand, neighborStrand, distanceLimit = constants.DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING, locationRequired = locationRequired)
					interestedUsers.extend(friends_util.filterUsersByFriends(user.id, friends, neighborStrand.users.all()))

					for friend in friends_util.filterUsersByFriends(user.id, friends, neighborStrand.users.all()):
						dist = geo_util.getDistanceBetweenStrands(strand, neighborStrand)
						matchReasons[friend.id] = "location-strand %s" % reason

				elif not locationRequired and strands_util.strandsShouldBeNeighbors(strand, neighborStrand, noLocationTimeLimitMin=3, distanceLimit = constants.DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING, locationRequired = locationRequired):
					interestedUsers.extend(friends_util.filterUsersByFriends(user.id, friends, neighborStrand.users.all()))

					for friend in friends_util.filterUsersByFriends(user.id, friends, neighborStrand.users.all()):
						matchReasons[friend.id] = "nolocation-strand"

			if strand.id in neighborUsersByStrandId:
				interestedUsers.extend(neighborUsersByStrandId[strand.id])
				for friend in neighborUsersByStrandId[strand.id]:
					matchReasons[friend.id] = "location-user"

		
		if len(interestedUsers) > 0:	
			interestedUsersByStrandId[strand.id] = list(set(interestedUsers))
			matchReasonsByStrandId[strand.id] = matchReasons

	filteredStrands = list()
	for strandId in interestedUsersByStrandId.keys():
		for strand in strandsWithNeighbors:
			if strand.id == strandId:
				filteredStrands.append(strand)
	
	return interestedUsersByStrandId, matchReasonsByStrandId, filteredStrands
	
"""
	Creates a cache which is a dictionary with the key being the strandId and the value
	a list of neighbor strands

	returns cache[strandId] = list(neighborStrand1, neighborStrand2...)
"""
def getStrandNeighborsCache(strands, friends):
	strandIds = Strand.getIds(strands)
	friendIds = [x.id for x in friends]

	strandNeighbors = StrandNeighbor.objects.prefetch_related('strand_1', 'strand_2', 'strand_1__photos', 'strand_2__photos', 'strand_1__users', 'strand_2__users').filter((Q(strand_1_id__in=strandIds) & Q(strand_2_user_id__in=friendIds)) | (Q(strand_1_user_id__in=friendIds) & Q(strand_2_id__in=strandIds)))
	
	neighborStrandsByStrandId = dict()
	neighborUsersByStrandId = dict()
	for strand in strands:
		for strandNeighbor in strandNeighbors:
			added = False
			if strand.id == strandNeighbor.strand_1_id:
				if strand.id not in neighborStrandsByStrandId:
					neighborStrandsByStrandId[strand.id] = list()
				if strandNeighbor.strand_2 and strandNeighbor.strand_2 not in neighborStrandsByStrandId[strand.id]:
					neighborStrandsByStrandId[strand.id].append(strandNeighbor.strand_2)
				if not strandNeighbor.strand_2:
					if strandNeighbor.distance_in_meters:
						if strandNeighbor.distance_in_meters > constants.DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING:
							continue
					if strand.id not in neighborUsersByStrandId:
						neighborUsersByStrandId[strand.id] = list()
					neighborUsersByStrandId[strand.id].append(strandNeighbor.strand_2_user)
					
			elif strand.id == strandNeighbor.strand_2_id:
				if strand.id not in neighborStrandsByStrandId:
					neighborStrandsByStrandId[strand.id] = list()
				if strandNeighbor.strand_1 not in neighborStrandsByStrandId[strand.id]:
					neighborStrandsByStrandId[strand.id].append(strandNeighbor.strand_1)

	return (neighborStrandsByStrandId, neighborUsersByStrandId)

"""
	Count the number of photos in suggestions that are of type 'friend-location'
"""
def getPhotoCountFromFeedObjects(feedObjects):
	count = 0
	for obj in feedObjects:
		if obj['type'] == "photo":
			count += 1
		elif 'objects' in obj and 'suggestion_type' in obj and obj['suggestion_type'] == 'friend-location':
			count += getPhotoCountFromFeedObjects(obj['objects'])

	return count

def getIncomingBadgeCount(user):
	count = 0

	# get a list of all shareInstances for this user that aren't started by this user
	shareInstances = ShareInstance.objects.prefetch_related('users').filter(users__in=[user.id]).exclude(user=user).order_by("-updated", "id")[:100]
	shareInstanceIds = ShareInstance.getIds(shareInstances)

	# get a list of all photo_evaluated actions by this user for those shareInstanceIds
	actions = Action.objects.filter(share_instance_id__in=shareInstanceIds).filter(user=user).filter(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED)

	# count how many shareInstanceids don't have an associated action
	actionsByShareInstanceId = dict()
	
	for action in actions:
		if action.share_instance_id not in actionsByShareInstanceId:
			actionsByShareInstanceId[action.share_instance_id] = list()
		actionsByShareInstanceId[action.share_instance_id].append(action)

	for shareInstance in shareInstances:
		if shareInstance.id not in actionsByShareInstanceId:
			count += 1

	return count

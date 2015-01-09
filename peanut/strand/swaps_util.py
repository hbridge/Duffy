import logging
import datetime

from django.db.models import Q

from strand import geo_util, friends_util, strands_util
from common.models import Photo, Strand, StrandNeighbor, Action, User

from common import stats_util, cluster_util, api_util

from peanut.settings import constants

logger = logging.getLogger(__name__)


###
### TODO(Derek): Reorganize this whole things
###

def getFeedObjectsForSwaps(user):
	responseObjects = list()
	
	# Do neighbor suggestions
	friendsIdList = friends_util.getFriendsIds(user.id)

	strandNeighbors = StrandNeighbor.objects.filter((Q(strand_1_user_id=user.id) & Q(strand_2_user_id__in=friendsIdList)) | (Q(strand_1_user_id__in=friendsIdList) & Q(strand_2_user_id=user.id)))
	strandIds = list()
	for strandNeighbor in strandNeighbors:
		if strandNeighbor.strand_1_user_id == user.id:
			strandIds.append(strandNeighbor.strand_1_id)
		else:
			strandIds.append(strandNeighbor.strand_2_id)

	timeCutoff = datetime.datetime.utcnow() - datetime.timedelta(days=30)
	strands = Strand.objects.prefetch_related('photos').filter(user=user).filter(private=True).filter(suggestible=True).filter(id__in=strandIds).filter(first_photo_time__gt=timeCutoff).order_by('-first_photo_time')[:20]

	# The prefetch for 'user' took a while here so just do it manually
	for strand in strands:
		for photo in strand.photos.all():
			photo.user = user
			
	strands = list(strands)
	stats_util.printStats("swaps-strands-fetch")

	neighborStrandsByStrandId, neighborUsersByStrandId = getStrandNeighborsCache(strands, friends_util.getFriends(user.id))
	stats_util.printStats("swaps-neighbors-cache")

	locationBasedGroups = getGroupsDataForPrivateStrands(user, strands, constants.FEED_OBJECT_TYPE_SWAP_SUGGESTION, neighborStrandsByStrandId = neighborStrandsByStrandId, neighborUsersByStrandId = neighborUsersByStrandId, locationRequired = True)

	stats_util.printStats("swap-groups")

	locationBasedGroups = filter(lambda x: x['metadata']['suggestible'], locationBasedGroups)
	locationBasedGroups = sorted(locationBasedGroups, key=lambda x: x['metadata']['time_taken'], reverse=True)
	locationBasedGroups = filterEvaluatedPhotosFromGroups(user, locationBasedGroups)
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
	stats_util.printStats("swaps-location-suggestions")
	
	# Last resort, try throwing in recent photos
	if len(responseObjects) < 3:
		now = datetime.datetime.utcnow()
		lower = now - datetime.timedelta(days=7)

		lastWeekObjects = getObjectsDataForSpecificTime(user, lower, now, "Last Week", rankNum)
		rankNum += len(lastWeekObjects)
	
		for objects in lastWeekObjects:
			responseObjects.append(objects)

		stats_util.printStats("swaps-recent-photos")
	return responseObjects


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


def getObjectsDataForSpecificTime(user, lower, upper, title, rankNum):
	strands = Strand.objects.prefetch_related('photos', 'user').filter(user=user).filter(private=True).filter(suggestible=True).filter(contributed_to_id__isnull=True).filter(Q(first_photo_time__gt=lower) & Q(first_photo_time__lt=upper))

	groups = getGroupsDataForPrivateStrands(user, strands, constants.FEED_OBJECT_TYPE_SWAP_SUGGESTION, neighborStrandsByStrandId=dict(), neighborUsersByStrandId=dict())
	groups = sorted(groups, key=lambda x: x['metadata']['time_taken'], reverse=True)
	groups = filterEvaluatedPhotosFromGroups(user, groups)
	
	objects = getObjectsDataFromGroups(groups)

	for suggestion in objects:
		suggestion['suggestible'] = True
		suggestion['suggestion_type'] = "timed-%s" % (title)
		suggestion['title'] = title
		suggestion['suggestion_rank'] = rankNum
		rankNum += 1
	return objects




# ------------------------
def getActorsObjectData(userId, users, includePhone = True):
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
	Creates a cache which is a dictionary with the key being the strandId and the value
	a list of neighbor strands

	returns cache[strandId] = list(neighborStrand1, neighborStrand2...)
"""
def getStrandNeighborsCache(strands, friends, withUsers = False):
	strandIds = Strand.getIds(strands)
	friendIds = [x.id for x in friends]

	strandNeighbors = StrandNeighbor.objects.prefetch_related('strand_1', 'strand_2').filter((Q(strand_1_id__in=strandIds) & Q(strand_2_user_id__in=friendIds)) | (Q(strand_1_user_id__in=friendIds) & Q(strand_2_id__in=strandIds)))

	if withUsers:
		strandNeighbors = strandNeighbors.prefetch_related('strand_1__users', 'strand_2__users')

	strandNeighbors = list(strandNeighbors)

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
	Returns back the objects data for private strands which includes neighbor_users.
	This gets the Strand Neighbors (two strands which are possible to strand together)

	Returns "groups", of the format of a list of dicts
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

"""
def getGroupsDataForPrivateStrands(thisUser, strands, feedObjectType, friends = None, neighborStrandsByStrandId = None, neighborUsersByStrandId = None, locationRequired = True, requireInterestedUsers = True, findInterestedUsers = True, filterOutEvaluated = True):
	groups = list()

	if friends == None:
		friends = friends_util.getFriends(thisUser.id)

	if (neighborStrandsByStrandId == None or neighborUsersByStrandId == None) and findInterestedUsers:
		neighborStrandsByStrandId, neighborUsersByStrandId = getStrandNeighborsCache(strands, friends)

	strandsToDelete = list()
	for strand in strands:
		photos = strand.photos.all()


		photos = sorted(photos, key=lambda x: x.time_taken, reverse=True)
		photos = filter(lambda x: x.install_num >= 0, photos)

		
		if len(photos) == 0:
			logger.warning("in getObjectsDataForPrivateStrands found strand with no photos: %s" % (strand.id))
			strandsToDelete.append(strand)
			continue
		
		title = ""
		matchReasons = dict()
		interestedUsers = list()
		if findInterestedUsers:
			if strand.id in neighborStrandsByStrandId:
				for neighborStrand in neighborStrandsByStrandId[strand.id]:
					if neighborStrand.location_point and strand.location_point and strands_util.strandsShouldBeNeighbors(strand, neighborStrand, distanceLimit = constants.DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING, locationRequired = locationRequired):
						val, reason = strands_util.strandsShouldBeNeighbors(strand, neighborStrand, distanceLimit = constants.DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING, locationRequired = locationRequired)
						interestedUsers.extend(friends_util.filterUsersByFriends(thisUser.id, friends, neighborStrand.users.all()))

						for user in friends_util.filterUsersByFriends(thisUser.id, friends, neighborStrand.users.all()):
							dist = geo_util.getDistanceBetweenStrands(strand, neighborStrand)
							matchReasons[user.id] = "location-strand %s" % reason

					elif not locationRequired and strands_util.strandsShouldBeNeighbors(strand, neighborStrand, noLocationTimeLimitMin=3, distanceLimit = constants.DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING, locationRequired = locationRequired):
						interestedUsers.extend(friends_util.filterUsersByFriends(thisUser.id, friends, neighborStrand.users.all()))
						
						for user in friends_util.filterUsersByFriends(thisUser.id, friends, neighborStrand.users.all()):
							matchReasons[user.id] = "nolocation-strand"

				if strand.id in neighborUsersByStrandId:
					interestedUsers.extend(neighborUsersByStrandId[strand.id])
					for user in neighborUsersByStrandId[strand.id]:
						matchReasons[user.id] = "location-user"
					
			interestedUsers = list(set(interestedUsers))

			if len(interestedUsers) > 0:
				title = "might like these photos"
	
		suggestible = strand.suggestible

		if suggestible and len(interestedUsers) == 0 and requireInterestedUsers:
			suggestible = False
			
		if not strands_util.getLocationForStrand(strand) and locationRequired:
			interestedUsers = list()
			suggestible = False

		metadata = {'type': feedObjectType, 'id': strand.id, 'match_reasons': matchReasons, 'strand_id': strand.id, 'title': title, 'time_taken': strand.first_photo_time, 'actors': getActorsObjectData(thisUser.id, interestedUsers), 'actor_ids': User.getIds(interestedUsers), 'suggestible': suggestible}
		entry = {'photos': photos, 'metadata': metadata}

		groups.append(entry)
	
	groups = sorted(groups, key=lambda x: x['photos'][0].time_taken, reverse=True)

	# These are strands that are found to have no valid photos.  So maybe they were all deleted photos
	# Can remove them here since they're private strands so something with no valid photos shouldn't exist
	for strand in strandsToDelete:
		logger.info("Deleting private strand %s for user %s" % (strand.id, thisUser.id))
		strand.delete()


	return groups

def getPhotoCountFromFeedObjects(feedObjects):
	count = 0
	for obj in feedObjects:
		if obj['type'] == "photo":
			count += 1
		else:
			count += getPhotoCountFromFeedObjects(obj['objects'])

	return count

def filterEvaluatedPhotosFromGroups(user, groups):
	photoIds = list()
	groupsToReturn = list()

	if len(groups) == 0:
		return groupsToReturn

	for group in groups:
		photoIds.extend(Photo.getIds(group['photos']))

	evalActions = Action.objects.filter(Q(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED) & Q(user=user) & Q(photo_id__in=photoIds))

	actionsByPhotoIdCache = dict()
	for action in evalActions:
		if action.photo_id not in actionsByPhotoIdCache:
			actionsByPhotoIdCache[action.photo_id] = list()
		actionsByPhotoIdCache[action.photo_id].append(action)

	
	for group in groups:
		# Have to make a list() of this since we need an independent copy to loop through
		photosNotEvaluated = list(group['photos'])
		for photo in group['photos']:
			if photo.id in actionsByPhotoIdCache:
				for action in actionsByPhotoIdCache[photo.id]:
					if photo in photosNotEvaluated:
						photosNotEvaluated.remove(photo)

		if len(photosNotEvaluated) == 0:
			continue
		else:
			group['photos'] = photosNotEvaluated
			groupsToReturn.append(group)

	return groupsToReturn

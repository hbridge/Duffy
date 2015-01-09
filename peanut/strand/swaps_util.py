import logging

from django.db.models import Q

from strand import geo_util, friends_util, strands_util
from common.models import Photo, Strand, StrandNeighbor, Action, User

from peanut.settings import constants

logger = logging.getLogger(__name__)



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

def getAllPhotosFromGroups(groups):
	photos = list()
	for group in groups:
		photos.extend(group['photos'])

	return photos

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

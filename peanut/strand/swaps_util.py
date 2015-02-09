import logging
import datetime
import pytz

from django.db.models import Q

from strand import geo_util, friends_util, strands_util
from common.models import Photo, Strand, StrandNeighbor, Action, User, ShareInstance

from common import stats_util, cluster_util, api_util, serializers

from peanut.settings import constants

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

# Need to create a key that is sortable, consistant (to deal with partial updates) and handles
# many photos shared at once
def getSortRanking(user, shareInstance, actions):
	lastTimestamp = shareInstance.shared_at_timestamp
	
	a = (long(lastTimestamp.strftime('%s')) % 1000000000) * 10000000
	b = long(shareInstance.photo.time_taken.strftime('%s')) % 10000000

	return -1 * (a + b)

def getFriendsObjectData(userId, users, includePhone = True):
	if not isinstance(users, list) and not isinstance(users, set):
		users = [users]

	fullFriends, forwardFriends, reverseFriends, connIds = friends_util.getFriendsIds(userId)

	userData = list()
	for user in users:
		if user.id == userId:
			continue

		entry = {'display_name': user.display_name, 'id': user.id}

		
		connId = None
		if user.id in fullFriends:
			relationship = constants.FEED_OBJECT_TYPE_RELATIONSHIP_FRIEND
			connId = connIds[user.id]
			entry['forward_friend_only'] = False
		elif user.id in forwardFriends and not user.id in fullFriends:
			relationship = constants.FEED_OBJECT_TYPE_RELATIONSHIP_FORWARD_FRIEND
			connId = connIds[user.id]
			entry['forward_friend_only'] = True
		elif user.id in reverseFriends:
			relationship = constants.FEED_OBJECT_TYPE_RELATIONSHIP_REVERSE_FRIEND
		else:
			relationship = constants.FEED_OBJECT_TYPE_RELATIONSHIP_USER
		
		entry[constants.FEED_OBJECT_TYPE_RELATIONSHIP] = relationship
		
		if connId:
			entry['friend_connection_id'] = connId
			
		if includePhone:
			entry['phone_number'] = user.phone_number

		userData.append(entry)

	return userData

def getPeopleListEntry(user, peopleIds):
	fullFriendsIds, forwardFriendsIds, reverseFriendsIds, connIds  = friends_util.getFriendsIds(user.id)
	peopleIds.extend(fullFriendsIds)
	peopleIds.extend(forwardFriendsIds)
	peopleIds.extend(reverseFriendsIds)

	people = list(User.objects.filter(id__in=set(peopleIds)))

	peopleEntry = {'type': constants.FEED_OBJECT_TYPE_FRIENDS_LIST, 'share_instance': -1, 'people': getFriendsObjectData(user.id, people, True)}		
	return peopleEntry


# Fetch strands we want to find neighbors on
# Fetch neighbors rows that match strands and friends
# Fetch neighbor strands and neighbor users
# Filter out eval'd photos
# Format private strand with interested users
def getFeedObjectsForSwaps(user):
	responseObjects = list()
	strandIdsAlreadyIncluded = list()

	fullFriends, forwardFriends, reverseFriends = friends_util.getFriends(user.id)

	# on dev, we want a larger window to test in simulators
	if '555555' in str(user.phone_number):
		days = 365
	else:
		days = 30

	timeCutoff = datetime.datetime.utcnow().replace(tzinfo=pytz.utc) - datetime.timedelta(days=days)
	recentStrands = Strand.objects.filter(user=user).filter(private=True).filter(first_photo_time__gt=timeCutoff).order_by('-first_photo_time')
	stats_util.printStats("swaps-recent-cache")
	
	interestedUsersByStrandId, matchReasonsByStrandId, strands = getInterestedUsersForStrands(user, recentStrands, True, fullFriends)
	stats_util.printStats("swaps-b")

	for strand in strands:
		strandObjectData = serializers.objectDataForPrivateStrand(user,
																  strand,
																  fullFriends,
																  True, # includeNotEval
																  False, # includeFaces
																  False, # includeAll
																  "friend-location", # suggestionType
																  interestedUsersByStrandId, matchReasonsByStrandId)
		if strandObjectData:
			strandIdsAlreadyIncluded.append(strand.id)
			# Make sure the photos appear in reverse order
			strandObjectData['objects'] = sorted(strandObjectData['objects'], key=lambda x: x['time_taken'], reverse=True)
			responseObjects.append(strandObjectData)

	responseObjects = sorted(responseObjects, key=lambda x: x['time_taken'], reverse=True)

	# Look for strands with faces
	for strand in recentStrands:
		strandObjectData = serializers.objectDataForPrivateStrand(user,
																  strand,
																  fullFriends,
																  False, # includeNotEval
																  True, # includeFaces
																  False, # includeAll
																  "faces", # suggestionType
																  interestedUsersByStrandId, matchReasonsByStrandId)

		if strandObjectData and strand.id not in strandIdsAlreadyIncluded:
			strandIdsAlreadyIncluded.append(strand.id)
			# Make sure the photos appear in reverse order
			strandObjectData['objects'] = sorted(strandObjectData['objects'], key=lambda x: x['time_taken'], reverse=True)
			responseObjects.append(strandObjectData)

	return responseObjects

def getFeedObjectsForPrivateStrands(user):
	responseObjects = list()

	fullFriends, forwardFriends, reverseFriends = friends_util.getFriends(user.id)

	allPrivateStrands = Strand.objects.prefetch_related('photos').filter(user=user).filter(private=True).order_by('-first_photo_time')
	for strand in allPrivateStrands:
		for photo in strand.photos.all():
			photo.user = user
	
	stats_util.printStats("private-all-cache")
	
	interestedUsersByStrandId, matchReasonsByStrandId, strands = getInterestedUsersForStrands(user, allPrivateStrands, True, fullFriends)
	stats_util.printStats("private-b")
		
	for strand in allPrivateStrands:
		strandObjectData = serializers.objectDataForPrivateStrand(user,
																  strand,
																  fullFriends,
																  True, # includeNotEval
																  True, # includeFaces
																  True, # includeAll
																  "", # suggestionType
																  interestedUsersByStrandId, matchReasonsByStrandId)

		if strandObjectData:
			responseObjects.append(strandObjectData)

	return responseObjects

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

"""
	Returns the list of last actions for a user
"""

def getActionsList(user):
	responseObjects = list()
	actionsData = list()

	# Do favorites and comments
	actions = Action.objects.prefetch_related('user', 'share_instance', 'photo').filter(photo__thumb_filename__isnull=False).exclude(user=user).filter(Q(action_type=constants.ACTION_TYPE_FAVORITE) | Q(action_type=constants.ACTION_TYPE_COMMENT)).filter(share_instance__users__in=[user.id]).order_by("-added")[:60]
	for action in actions:
		actionData = serializers.actionDataOfActionApiSerializer(user, action)
		if actionData:
			actionsData.append(actionData)

	# Do shares to this user
	shareInstances = ShareInstance.objects.filter(photo__thumb_filename__isnull=False).filter(users__in=[user.id]).order_by("-added", "-id")[:100]
	for shareInstance in shareInstances:
		actionData = serializers.actionDataOfShareInstanceApiSerializer(user, shareInstance)

		if actionData:
			actionsData.append(actionData)

	actionsData = sorted(actionsData, key=lambda x: x['time_stamp'], reverse=True)

	actionsData = compressActions(actionsData)[:50]
	return actionsData

def compressGroup(lastActionData, count):
	if count == 1:
		lastActionData['text'] = "sent 1 photo"
	else:
		lastActionData['text'] = "sent %s photos" % count

	# Also update the ID to be unique.  Multiple existing id by count to make unique
	lastActionData['id'] = count * lastActionData['id']

	return lastActionData

def compressActions(actionsData):
	# We want to group together all the photos shared around the same time
	lastActionData = None
	count = 1
	doingCompress = False
	compressedActionsData = list()

	for actionData in actionsData:
		if actionData['action_type'] == constants.ACTION_TYPE_SHARED_PHOTOS:
			if not doingCompress:
				doingCompress = True
				count = 1

			if not lastActionData:
				lastActionData = actionData
			else:
				if (lastActionData['action_type'] == constants.ACTION_TYPE_SHARED_PHOTOS and
					actionData['action_type'] == constants.ACTION_TYPE_SHARED_PHOTOS and
					lastActionData['user'] == actionData['user'] and 
					abs((lastActionData['time_stamp'] - actionData['time_stamp']).total_seconds()) < constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING * 60):
					count += 1
					lastActionData = actionData
				else:
					compressedActionsData.append(compressGroup(lastActionData, count))

					count = 1
					lastActionData = actionData
		else:
			if doingCompress:
				compressedActionsData.append(compressGroup(lastActionData, count))
				doingCompress = False
				lastActionData = None
			compressedActionsData.append(actionData)

	if doingCompress:
		compressedActionsData.append(compressGroup(lastActionData, count))

	return compressedActionsData


def getActionsListUnreadCount(user, actionsData):
	count = 0
	if user.last_actions_list_request_timestamp:
		for actions in actionsData:
			if actions['time_stamp'] > user.last_actions_list_request_timestamp:
				count += 1
		return count
	else:
		return len(actionsData)

def getFeedObjectsForInbox(user, lastTimestamp, num):
	responseObjects = list()

	# Grab all share instances we want.  Might filter by a last timestamp for speed
	shareInstances = ShareInstance.objects.prefetch_related('photo', 'users', 'photo__user').filter(users__in=[user.id]).order_by("-updated", "id")

	if lastTimestamp:
		shareInstances = shareInstances.filter(updated__gt=lastTimestamp)
	if num:
		shareInstances = shareInstances[:num]

	# The above search won't find photos that this user has evaluated if the last_action_timestamp
	# is before the given lastTimestamp
	# So in that case, lets search for all the actions since that timestamp and add those
	# ShareInstances into the mix to be sorted
	recentlyEvaluatedActions = Action.objects.prefetch_related('share_instance', 'share_instance__photo', 'share_instance__users', 'share_instance__photo__user').filter(user=user).filter(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED).order_by('-added')
	if lastTimestamp:
		recentlyEvaluatedActions = recentlyEvaluatedActions.filter(updated__gt=lastTimestamp)
	if num:
		recentlyEvaluatedActions = recentlyEvaluatedActions[:num]
		
	shareInstanceIds = ShareInstance.getIds(shareInstances)
	shareInstances = list(shareInstances)
	for action in recentlyEvaluatedActions:
		if action.share_instance_id and action.share_instance_id not in shareInstanceIds:
			shareInstances.append(action.share_instance)
	
	
	# Now grab all the actions for these ShareInstances (comments, evals, likes)
	shareInstanceIds = ShareInstance.getIds(shareInstances)
	stats_util.printStats("swaps_inbox-1")

	actions = Action.objects.filter(share_instance_id__in=shareInstanceIds)
	actionsByShareInstanceId = dict()
	
	for action in actions:
		if action.share_instance_id not in actionsByShareInstanceId:
			actionsByShareInstanceId[action.share_instance_id] = list()
		actionsByShareInstanceId[action.share_instance_id].append(action)

	stats_util.printStats("swaps_inbox-2")

	# Loop through all the share instances and create the feed data
	for shareInstance in shareInstances:
		actions = list()
		if shareInstance.id in actionsByShareInstanceId:
			actions = actionsByShareInstanceId[shareInstance.id]

		actions = uniqueObjects(actions)
		objectData = serializers.objectDataForShareInstance(shareInstance, actions, user)

		# Might be filtered out due to missing thumb
		if objectData:
			# suggestion_rank here for backwards compatibility, remove upon next mandatory updatae after Jan 2
			objectData['sort_rank'] = getSortRanking(user, shareInstance, actions)
			objectData['suggestion_rank'] = objectData['sort_rank']
			responseObjects.append(objectData)

	responseObjects = sorted(responseObjects, key=lambda x: x['sort_rank'])
	
	count = 0
	for responseObject in responseObjects:
		responseObject["debug_rank"] = count
		count += 1

	stats_util.printStats("swaps_inbox-3")
	return responseObjects

def getUnseenPhotoCount(user):

	# calculate timestamp
	# Use greater of user.last_actions_list_request_timestamp or last action taken by the user
	lastActionTimestamp = getLastActionTimestampByUser(user)

	if lastActionTimestamp > user.last_actions_list_request_timestamp:
		timestamp = lastActionTimestamp
	else:
		timestamp = user.last_actions_list_request_timestamp

	responseObjects = getFeedObjectsForInbox(user, timestamp, 100)

	count = 0

	for responseObject in responseObjects:
		if responseObject['evaluated'] == False:
			count += 1

	return count

def getLastActionTimestampByUser(user):
	actions = Action.objects.filter(user=user).order_by('-added')

	if len(actions) > 0:
		return action[0].added
	else:
		return datetime.datetime.fromtimestamp(0)


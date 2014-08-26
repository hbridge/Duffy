from django.db.models import Q

from common.models import FriendConnection

"""
	Return friends and friends of friends ids for the given user
"""
def getFriendsData(userId):
	friendConnections = FriendConnection.objects.select_related().filter(Q(user_1=userId) | Q(user_2=userId))

	friendsIds = list()
	for friendConnection in friendConnections:
		if (friendConnection.user_1.id != userId):
			friendsIds.append(friendConnection.user_1.id)
		else:
			friendsIds.append(friendConnection.user_2.id)

	friendsOfFriendsConnections = FriendConnection.objects.select_related().filter(Q(user_1__in=friendsIds) | Q(user_2__in=friendsIds))
	friendsOfFriendsIds = list()
	for friendsOfFriendConnection in friendsOfFriendsConnections:
		if (friendsOfFriendConnection.user_1.id in friendsIds):
			friendsOfFriendsIds.append(friendsOfFriendConnection.user_2.id)
		if (friendsOfFriendConnection.user_2.id in friendsIds):
			friendsOfFriendsIds.append(friendsOfFriendConnection.user_1.id)

	friendsOfFriendsIds = set(friendsOfFriendsIds)
	return (friendsIds, friendsOfFriendsIds, friendsOfFriendsConnections)

"""
	For a given userId, should they be included as a "friend"
	This is defined by the fact that they have a direct connection to our user
	Or if they're a friend of a friend that 
"""
def shouldUserBeIncluded(userId, evalUserId, friendsData, presentUsers):
	friendsIds, friendsOfFriendsIds, friendsOfFriendsConnections = friendsData
	includedUsers = list()

	# If evaluated user is a direct friend
	if evalUserId in friendsIds:
		return True

	# if evaluated users is aa friend of a friend and the mutual friend is present
	if evalUserId in friendsOfFriendsIds:
		for friendsOfFriendsConnection in friendsOfFriendsConnections:
			if (friendsOfFriendsConnection.user_1.id == evalUserId and
				friendsOfFriendsConnection.user_2 in presentUsers):
				return True
			if (friendsOfFriendsConnection.user_2.id == evalUserId and
				friendsOfFriendsConnection.user_1 in presentUsers):
				return True

	return False

"""
	Return back a list of photos that either belong to a friend or the given user
"""
def filterStrandPhotosByFriends(userId, friendsData, strand):
	return strand.photos.all().order_by("-time_taken")

	"""
	presentUsers = strand.users.all()

	resultPhotos = list()
	for photo in strand.photos.all().order_by("-time_taken"):
		if shouldUserBeIncluded(userId, photo.user_id, friendsData, presentUsers) or photo.user_id == userId:
			resultPhotos.append(photo)

	return resultPhotos
	"""

"""
	Return back a list of users that are in the friends list
"""
def filterUsersByFriends(userId, friendsData, presentUsers):
	return presentUsers

	"""
	resultUsers = list()
	for user in presentUsers:
		if shouldUserBeIncluded(userId, user.id, friendsData, presentUsers):
			resultUsers.append(user)

	return resultUsers
	"""
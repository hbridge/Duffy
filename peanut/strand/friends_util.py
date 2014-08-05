from django.db.models import Q

from common.models import FriendConnection

"""
	Return friends and friends of friends ids for the given user
"""
def getFriendsIds(userId):
	friendConnections = FriendConnection.objects.select_related().filter(Q(user_1=userId) | Q(user_2=userId))

	friendsIds = list()
	for friendConnection in friendConnections:
		if (friendConnection.user_1.id != userId):
			friendsIds.append(friendConnection.user_1.id)
		else:
			friendsIds.append(friendConnection.user_2.id)

	friendsOfFriendConnections = FriendConnection.objects.select_related().filter(Q(user_1__in=friendsIds) | Q(user_2__in=friendsIds))
	for friendsOfFriendConnection in friendsOfFriendConnections:
		if (friendsOfFriendConnection.user_1.id != userId):
			friendsIds.append(friendsOfFriendConnection.user_1.id)
		if (friendsOfFriendConnection.user_2.id != userId):
			friendsIds.append(friendsOfFriendConnection.user_2.id)

	friendsIds = set(friendsIds)
	return friendsIds

"""
	Return back a list of photos that either belong to a friend or the given user
"""
def filterPhotosByFriends(userId, friendIds, photos):
	resultPhotos = list()
	for photo in photos:
		if photo.user_id in friendIds or photo.user_id == userId:
			resultPhotos.append(photo)

	return resultPhotos

"""
	Return back a list of users that are in the friends list
"""
def filterUsersByFriends(userId, friendIds, users):
	resultUsers = list()
	for user in users:
		if user.id in friendIds:
			resultUsers.append(user)

	return resultUsers
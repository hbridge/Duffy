from django.db.models import Q

from common.models import FriendConnection

"""
	Return friends and friends of friends ids for the given user
"""
def getFriends(userId):
	friendConnections = FriendConnection.objects.select_related().filter(Q(user_1=userId) | Q(user_2=userId))

	fullFriends = list()
	reverseFriends = list()
	forwardFriends = list()
	for friendConnection in friendConnections:
		if (friendConnection.user_1.id == userId):
			forwardFriends.append(friendConnection.user_2)
			if friendConnection.user_2 in reverseFriends:
				fullFriends.append(friendConnection.user_2)
		else:
			reverseFriends.append(friendConnection.user_1)
			if friendConnection.user_1 in forwardFriends:
				fullFriends.append(friendConnection.user_1)

	return fullFriends, forwardFriends, reverseFriends


"""
	Return friends and friends of friends ids for the given user
"""
def getFriendsIds(userId):
	friendConnections = FriendConnection.objects.filter(Q(user_1=userId) | Q(user_2=userId))

	fullFriends = list()
	reverseFriends = list()
	forwardFriends = list()
	for friendConnection in friendConnections:
		if (friendConnection.user_1_id == userId):
			forwardFriends.append(friendConnection.user_2_id)
			if friendConnection.user_2_id in reverseFriends:
				fullFriends.append(friendConnection.user_2_id)
		else:
			reverseFriends.append(friendConnection.user_1_id)
			if friendConnection.user_1_id in forwardFriends:
				fullFriends.append(friendConnection.user_1_id)

	return fullFriends, forwardFriends, reverseFriends

"""
	For a given userId, should they be included as a "friend"
	This is defined by the fact that they have a direct connection to our user
	Or if they're a friend of a friend that 
"""
def shouldUserBeIncluded(userId, evalUser, friends):
	includedUsers = list()

	friendsIds = [friend.id for friend in friends]
	# If evaluated user is a direct friend
	if evalUser.id in friendsIds:
		return True

	return False

"""
	Return back a list of photos that either belong to a friend or the given user
"""
def filterStrandPhotosByFriends(userId, friends, strand):
	photos = sorted(strand.photos.all(), key=lambda x: x.time_taken, reverse=True)

	return photos

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
def filterUsersByFriends(userId, friends, users):
	resultUsers = list()
	for user in users:
		if shouldUserBeIncluded(userId, user, friends):
			resultUsers.append(user)

	return resultUsers
	

from django.db.models import Q

from common.models import FriendConnection, SharedStrand

"""
	Return friends and friends of friends ids for the given user
"""
def getFriends(userId):
	friendConnections = FriendConnection.objects.select_related().filter(Q(user_1=userId) | Q(user_2=userId))

	friends = list()
	for friendConnection in friendConnections:
		if (friendConnection.user_1.id != userId):
			friends.append(friendConnection.user_1)
		else:
			friends.append(friendConnection.user_2)

	friends = sorted(friends, key=lambda x: x.display_name)
	return friends


"""
	Return friends and friends of friends ids for the given user
"""
def getSharedStrands(userId, friends):
	ids = [x.id for x in friends]
	ids.append(userId)

	sharedStrands = SharedStrand.objects.prefetch_related('users').filter(users__in=ids)

	return sharedStrands

def getSharedStrandForUserIds(sharedStrands, userIds):
	for sharedStrand in sharedStrands:
		if len(sharedStrand.users.all()) == len(userIds):
			notFoundUsers = list(sharedStrand.users.all())
			for user in sharedStrand.users.all():
				if user.id in userIds:
					notFoundUsers.remove(user)

			if len(notFoundUsers) == 0:
				return sharedStrand.strand
	return None


"""
	Return friends and friends of friends ids for the given user
"""
def getFriendsIds(userId):
	friendConnections = FriendConnection.objects.filter(Q(user_1=userId) | Q(user_2=userId))

	friendsIds = list()
	for friendConnection in friendConnections:
		if (friendConnection.user_1_id != userId):
			friendsIds.append(friendConnection.user_1_id)
		else:
			friendsIds.append(friendConnection.user_2_id)

	return friendsIds

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
	

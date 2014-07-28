#!/usr/bin/python
import sys, os
import time, datetime
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

from django.db.models import Count
from django.db import IntegrityError

from common.models import User, ContactEntry, FriendConnection
from arbus import similarity_util

"""
	Returns a dictionary keyed by phone number and value is user
"""
def getUsersByPhoneNumber(users):
	usersByPhoneNumber = dict()

	for user in users:
		usersByPhoneNumber[str(user.phone_number)] = user

	return usersByPhoneNumber

"""
	Returns a dictionary of dictionaires, first keyed by user, second by phone number
	If the entry exists, then that user has that phone number in their contacts
"""
def getContactsByUser(contactEntries):
	contactsByUser = dict()

	for contactEntry in contactEntries:
		if contactEntry.user not in contactsByUser:
			contactsByUser[contactEntry.user] = dict()
		contactsByUser[contactEntry.user][str(contactEntry.phone_number)] = True

	return contactsByUser
	
"""
	Populate the Friends table.  This creates a link between two users
	Loop through all unprocessed ContactEntries and for each one, see if there is a phone number
	in our db for the ContactEntry.  If so, and the other user has the current user's number, add a 
	Friend entry

"""
def main(argv):
	logger = logging.getLogger(__name__)
	
	logger.info("Starting... ")
	while True:
		contactEntries = ContactEntry.objects.select_related().filter(evaluated=False)[:100]
		newConnectionCount = 0

		if len(contactEntries) > 0:
			# Grab users who these new contact entries point to
			phoneNumbers = [contactEntry.phone_number for contactEntry in contactEntries]
			users = User.objects.filter(phone_number__in=phoneNumbers)

			usersByPhoneNumber = getUsersByPhoneNumber(users)

			# Now, look through each of those user's contacts to see if there's a corrisponding entry
			usersToFetchContactsFor = list()
			for contactEntry in contactEntries:
				if str(contactEntry.phone_number) in usersByPhoneNumber:
					usersToFetchContactsFor.append(usersByPhoneNumber[str(contactEntry.phone_number)].id)

			usersToFetchContactsFor = set(usersToFetchContactsFor)

			possibleFriendEntries = ContactEntry.objects.filter(user_id__in=usersToFetchContactsFor)

			possibleFriendEntriesByUser = getContactsByUser(possibleFriendEntries)
			
			for contactEntry in contactEntries:
				# If we have a user associated with a given phone number
				if str(contactEntry.phone_number) in usersByPhoneNumber:
					possibleFriend = usersByPhoneNumber[str(contactEntry.phone_number)]

					# And the possible Friend also has the reverse mapping for this contact
					#   The possible friend won't be in the possibleFriendEntriesByUser dict
					#   if we don't have any contacts from them
					if (possibleFriend in possibleFriendEntriesByUser and 
					  str(contactEntry.user.phone_number) in opposingContactEntriesByUser[opposingUser]):
						try:
							# Yay!  lets make a Friend entry
							# Lower id will go first
							if contactEntry.user.id < opposingUser.id:
								FriendConnection.objects.create(user_1=contactEntry.user, user_2=opposingUser)
							else:
								FriendConnection.objects.create(user_1=opposingUser, user_2=contactEntry.user)

							newConnectionCount += 1
						except IntegrityError:
							logger.warning("Tried to create friend connection between %s and %s but there was one already" % (contactEntry.user.id, opposingUser.id))

				contactEntry.evaluated = True

			logger.info("Wrote out %s friend entries after evaluating %s contact entries" % (newConnectionCount, len(contactEntries)))
			ContactEntry.bulkUpdate(contactEntries, ["evaluated"])
		else:
			time.sleep(1)	

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/friends.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
from __future__ import absolute_import
import sys, os
import time, datetime
import logging
from threading import Thread

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.db.models import Count
from django.db import IntegrityError

from common.models import User, ContactEntry, FriendConnection, Action
from arbus import similarity_util

from strand import notifications_util

from peanut.settings import constants

from peanut.celery import app

from async import celery_helper
from async import suggestion_notifications, notifications
from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)


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
			
		try:
			contactsByUser[contactEntry.user][str(contactEntry.phone_number)] = True
		except UnicodeEncodeError:
			logging.error("Unicode Encode Error for contact entry %s" % contactEntry.id)
			contactEntry.skip = True
			contactEntry.save()


	return contactsByUser
	
"""
	Populate the Friends table.  This creates a link between two users
	Loop through all unprocessed ContactEntries and for each one, see if there is a phone number
	in our db for the ContactEntry.  If so, and the other user has the current user's number, add a 
	Friend entry

"""
def processBatch(contactEntries):
	newConnectionCount = 0

	if len(contactEntries) > 0:
		# Grab users who these new contact entries point to
		phoneNumbers = [contactEntry.phone_number for contactEntry in contactEntries]
		users = User.objects.filter(phone_number__in=phoneNumbers).filter(product_id=2)

		usersByPhoneNumber = getUsersByPhoneNumber(users)

		actionIdsToNotify = list()
		for contactEntry in contactEntries:
			contactEntry.evaluated = True
			
			# If we have a user associated with a given phone number
			if contactEntry.phone_number in usersByPhoneNumber:
				forwardFriend = usersByPhoneNumber[contactEntry.phone_number]
				try:
					if contactEntry.user.id == forwardFriend.id:
						continue
					else:
						if FriendConnection.addForwardConnection(contactEntry.user, forwardFriend):
							# TODO: Probably should be turned into a bulkcreate at some point.
							action = Action.objects.create(user_id=contactEntry.user.id, action_type=constants.ACTION_TYPE_ADD_FRIEND, text='added you as a friend', target_user_id=forwardFriend.id)
							actionIdsToNotify.append(action.id)

							newConnectionCount += 1
						if contactEntry.contact_type and 'invited' in contactEntry.contact_type:
							if FriendConnection.addReverseConnection(contactEntry.user, forwardFriend):
								newConnectionCount +=1
							
				except IntegrityError:
					logger.warning("Tried to create friend connection between %s and %s but there was one already" % (contactEntry.user.id, friend.id))

		logger.info("Wrote out %s friend entries after evaluating %s contact entries" % (newConnectionCount, len(contactEntries)))
		ContactEntry.bulkUpdate(contactEntries, ["evaluated"])

		usersIdsToUpdate = [contactEntry.user_id for contactEntry in contactEntries]
		usersIdsToUpdate = set(usersIdsToUpdate)

		for userId in usersIdsToUpdate:
			suggestion_notifications.processUserId.delay(userId)

		if len(actionIdsToNotify) > 0:
			notifications.sendAddFriendNotificationFromActions.delay(actionIdsToNotify)

		notifications.sendRefreshFeedToUserIds.delay(usersIdsToUpdate)

		return len(contactEntries)
	return 0

	

baseQuery = ContactEntry.objects.select_related().filter(evaluated=False).filter(skip=False).filter(user_id__gt=600)
numToProcess = 1000

@app.task
def processAll():
	return celery_helper.processBatch(baseQuery, numToProcess, processBatch)

@app.task
def processIds(ids):
	return celery_helper.processBatch(baseQuery.filter(id__in=ids), numToProcess, processBatch)


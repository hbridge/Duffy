#!/usr/bin/python
import sys, os, requests, json
import pytz
import logging
import datetime
import collections
from dateutil.relativedelta import relativedelta

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut.settings import constants
from common.models import User, FriendConnection, Action, Photo, StrandNeighbor, Strand, ShareInstance

from django.db.models import Count, Sum

from async import stranding


# This script remove duplicate private strands
def main(argv):
	print 'Starting...'

	now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
	delta = datetime.timedelta(weeks=2)
	shareInstances = ShareInstance.objects.filter(added__gt=(now-delta))
	actions = Action.objects.filter(added__gt=(now-delta))

	exactCount = 0

	totalSuggestions = 0

	activityCount = 0

	userSuggestionsCount = dict()
	userActionCount = dict()
	userShareCount = dict()
	userShareSuggestionCount = dict()

	for action in actions:
		if action.action_type == constants.ACTION_TYPE_SUGGESTION:
			if action.user_id not in userSuggestionsCount:
				userSuggestionsCount[action.user_id] = 0
				userActionCount[action.user_id] = 0
				userShareCount[action.user_id] = 0
				userShareSuggestionCount[action.user_id] = 0

			userSuggestionsCount[action.user_id] += 1
			
			# see if any action happened after this:
			hadActivity = False
			for a in actions:
				timeDiff = a.added - action.added
				timeDiff = timeDiff.total_seconds()
				if a.user_id == action.user_id and timeDiff > -30 and timeDiff < 60*60*3 and a.id != action.id:
					hadActivity = True

			

			# Now see if there's a share instance
			
			strands = action.photo.strand_set.filter(private=True)

			photoIds = list()
			for strand in strands:
				photoIds.extend(Photo.getIds(strand.photos.all()))

			didShare = False
			didShareSuggestion = False
			for shareInstance in shareInstances:
				timeDiff = shareInstance.shared_at_timestamp - action.added
				timeDiff = timeDiff.total_seconds()

				if timeDiff > -30 and timeDiff < 60*60*3:
					# See if they shared anything, counts as an action
					if shareInstance.user_id == action.user_id:
						hadActivity = True
						didShare = True

						if shareInstance.photo_id in photoIds:
							didShareSuggestion = True

							if shareInstance.photo_id == action.photo_id:
								print "Found share instance %s from exact action %s  timeDiff: %s seconds" % (shareInstance.id, action.id, timeDiff)	

			if hadActivity:
				userActionCount[action.user_id] += 1

			if didShare:
				userShareCount[action.user_id] += 1

			if didShareSuggestion:
				userShareSuggestionCount[action.user_id] += 1
				
			totalSuggestions += 1

	tookAction = 0
	didShare = 0
	totalUsers = 0

	totalShare = 0
	totalShareSuggestion = 0
	od = collections.OrderedDict(sorted(userSuggestionsCount.items()))

	for userId, count in od.iteritems():
		totalUsers += 1
		print "id: %s  suggestionCount: %s  actionCount: %s   shareCount: %s  shareSuggestionCount: %s" % (userId, count, userActionCount[userId], userShareCount[userId], userShareSuggestionCount[userId])

		if userActionCount[userId] > 0:
			tookAction += 1
		if userShareCount[userId] > 0:
			didShare += 1

		totalShare += userShareCount[userId]
		totalShareSuggestion += userShareSuggestionCount[userId]


	per = (float(totalShareSuggestion) / float(totalShare))*100

	print "Out of %s users, %s took actions and %s shared something (%s of the time it was the suggestion)" % (totalUsers, tookAction, didShare, per)
	print 'Finished...'
		
if __name__ == "__main__":

	main(sys.argv[1:])
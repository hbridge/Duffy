import os, sys
import logging
import datetime
import pytz
import json
import time
from threading import Thread

from django.db.models import Q
from django.conf import settings


parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django

django.setup()

from strand import swaps_util, friends_util
from common.models import Strand, User, ApiCache

from common import stats_util, serializers, api_util
import strand.notifications_util as notifications_util

from peanut.settings import constants

logger = logging.getLogger(__name__)

def threadedSendNotifications(userIds):
	time.sleep(1)
	logging.basicConfig(filename='/var/log/duffy/stranding.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	logger = logging.getLogger(__name__)

	users = User.objects.filter(id__in=userIds)

	# Send update feed msg to folks who are involved in these photos
	notifications_util.sendRefreshFeedToUsers(users)

def processPrivateStrands(num):
	# Look for all private strands that are dirty
	dirtyStrands = Strand.objects.prefetch_related('photos').filter(user__isnull=False).filter(cache_dirty=True).filter(private=True).order_by('-first_photo_time')[:num]

	# Group by user
	dirtyStrandsByUserId = dict()

	for strand in dirtyStrands:
		if strand.user_id not in dirtyStrandsByUserId:
			dirtyStrandsByUserId[strand.user_id] = list()
		dirtyStrandsByUserId[strand.user_id].append(strand)

	for userId, strandList in dirtyStrandsByUserId.iteritems():
		try:
			user = User.objects.get(id=userId)
		except User.DoesNotExist:
			logger.error("Couldn't find user: %s" % userId)
			continue
			
		friends = friends_util.getFriends(user.id)

		for strand in strandList:
			for photo in strand.photos.all():
				photo.user = user

		interestedUsersByStrandId, matchReasonsByStrandId, strands = swaps_util.getInterestedUsersForStrands(user, strandList, True, friends)

		try:
			apiCache = ApiCache.objects.get(user_id=user.id)
		except ApiCache.DoesNotExist:
			apiCache = ApiCache.objects.create(user=user)

		responseObjectsById = dict()
		if apiCache.private_strands_data:
			responseObjects = json.loads(apiCache.private_strands_data)['objects']

			for responseObject in responseObjects:
				responseObjectsById[responseObject['id']] = responseObject

		for strand in strandList:
			strandObjectData = serializers.objectDataForPrivateStrand(user, strand, friends, True, "", interestedUsersByStrandId, matchReasonsByStrandId, dict())
			if strandObjectData:
				responseObjectsById[strandObjectData['id']] = strandObjectData

			strand.cache_dirty = False
		responseObjects = responseObjectsById.values()
		responseObjects = sorted(responseObjects, key=lambda x: x['time_taken'], reverse=True)

		response = dict()
		response['objects'] = responseObjects
		apiCache.private_strands_data = json.dumps(response, cls=api_util.DuffyJsonEncoder)
		apiCache.private_strands_data_last_timestamp = datetime.datetime.utcnow()

		apiCache.save()

		Strand.bulkUpdate(strandList, ['cache_dirty'])

	Thread(target=threadedSendNotifications, args=(dirtyStrandsByUserId.keys(),)).start()

	return len(dirtyStrands)

def main(argv):
	stats_util.startProfiling()
	
	while True:
		strandsProcessed = processPrivateStrands(50)

		if strandsProcessed == 0:
			time.sleep(.1)
		else:
			for strand in strandsProcessed:
				logger.info("Processed strand %s" % (strand.id))

		logger.info("Finished processing %s strands" % (len(strandsProcessed)))
	# Find all interested users for those strands
	# Fetch current api cache
	# Update each of the strand entries
	# Re-sort
	# Write api entry
	# Mark strand as clean

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/popcache.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])
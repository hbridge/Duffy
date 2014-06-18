#!/usr/bin/python
import sys, os
import time, datetime
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.db.models import Count
from django.db.models import Q

from peanut import settings
from common.models import Neighbor, NotificationLog

import strand.notifications_util as notifications_util

def cleanName(str):
	return str.split(' ')[0].split("'")[0].split('’')[0]


def main(argv):
	maxFilesAtTime = 100
	logger = logging.getLogger(__name__)
	
	logger.info("Starting... ")
	while True:
		"""
			Get all rows from Neighbor table in last 30 seconds
			Get all rows from NotificationLog table in last 60 seconds
			(can get this of second query by storing last notification time in the user table)
			create dictionary per user on last notification time
			for each row in neighbor table:
				for each user 
					look up the last notification time
					if notification_time > 1 hr, 
						if they should get a notification (they have the older photo in the neighbor row)
							send notification


		"""
		startTime = datetime.datetime.utcnow()-datetime.timedelta(seconds=30)
		neighbors = Neighbor.objects.select_related().filter(Q(photo_1__time_taken__gt=startTime) | Q(photo_2__time_taken__gt=startTime)).order_by('photo_1')
		notLogs = NotificationLog.objects.select_related().filter(added__gt=datetime.datetime.utcnow()-datetime.timedelta(seconds=3600))
		lastNotTime = dict()

		if (len(neighbors) > 0):
			# create a dictionary per user on last notification time
			for notLog in notLogs:
				if notLog.user.id in lastNotTime:
					if (lastNotTime[notLog.user.id] < notLog.added):
						lastNotTime[notLog.user.id] = notLog.added
				else:
					lastNotTime[notLog.user.id] = notLog.added

			for neighbor in neighbors:
				if (neighbor.user_1.id not in lastNotTime and 
					neighbor.photo_1.time_taken < neighbor.photo_2.time_taken):
						msg = cleanName(neighbor.user_2.first_name) + " added new photos!"
						logger.debug("Sending message '%s' to user %s" % (msg, neighbor.user_1_id))						
						notifications_util.sendNotification(neighbor.user_1, msg)
						lastNotTime[neighbor.user_1_id] = datetime.datetime.utcnow()
				if (neighbor.user_2.id not in lastNotTime and 
					neighbor.photo_2.time_taken < neighbor.photo_1.time_taken):
						msg = cleanName(neighbor.user_1.first_name) + " added new photos!"
						notifications_util.sendNotification(neighbor.user_2, msg)
						logger.debug("Sending message '%s' to user %s" % (msg, neighbor.user_2_id))
						lastNotTime[neighbor.user_2_id] = datetime.datetime.utcnow()
			time.sleep(5)
		else:
			time.sleep(5)




if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/strand-notifications.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
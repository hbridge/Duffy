#!/usr/bin/python
import sys
import os
import datetime
import pytz
import logging

parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0], "..")

if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.models import User, Entry, Message
from smskeeper import keeper_constants, user_util
from common import date_util

logger = logging.getLogger(__name__)

"""
def main(argv):
	print "Starting..."

	userList = User.objects.all()

	for user in userList:
		user.done_count = len(Entry.objects.filter(creator=user, label="#reminders", hidden=True, remind_last_notified__isnull=False))
		user.save()

		print "processed %s %s" % (user.id, user.done_count)
	print "Donezo!"

if __name__ == "__main__":
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])


"""


def main(argv):
	print "Starting..."
	now = date_util.now(pytz.utc)
	cutoff = now - datetime.timedelta(days=7)

	userList = User.objects.filter(id__gt=1400)

	stoppedBuckets = dict()
	suspendedBuckets = dict()
	activeBuckets = dict()

	for x in range(11):
		stoppedBuckets[x] = 0
		suspendedBuckets[x] = 0
		activeBuckets[x] = 0

	for user in userList:
		state = user.state

		lastMessageIn = Message.objects.filter(user=user, incoming=True).order_by("added").last()

		futureReminders = user_util.pendingTodoEntries(user, includeAll=True, after=now)
		if lastMessageIn and lastMessageIn.added < cutoff and len(futureReminders) == 0 and state != keeper_constants.STATE_STOPPED:
			state = keeper_constants.STATE_SUSPENDED

		if state == keeper_constants.STATE_STOPPED:
			if user.done_count < 10:
				stoppedBuckets[user.done_count] += 1
			else:
				stoppedBuckets[10] += 1
		elif state == keeper_constants.STATE_SUSPENDED:
			if user.done_count < 10:
				suspendedBuckets[user.done_count] += 1
			else:
				suspendedBuckets[10] += 1
		else:
			if user.done_count < 10:
				activeBuckets[user.done_count] += 1
			else:
				activeBuckets[10] += 1

	print "Stopped:"
	for x in range(11):
		print "%s %s" % (x, stoppedBuckets[x])

	print "Suspended:"
	for x in range(11):
		print "%s %s" % (x, suspendedBuckets[x])

	print "Active:"
	for x in range(11):
		print "%s %s" % (x, activeBuckets[x])

	print "Donezo!"

if __name__ == "__main__":
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])

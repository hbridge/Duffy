#!/usr/bin/python
import sys
import os

import logging

parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0], "..")

if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.models import User, Entry
from smskeeper import keeper_constants

logger = logging.getLogger(__name__)


def main(argv):
	print "Starting..."

	userList = User.objects.filter(state=keeper_constants.STATE_STOPPED)

	for user in userList:
		reminders = Entry.objects.filter(creator=user, label="#reminders", hidden=False)

		for reminder in reminders:
			print "Processing: %s" % reminder.id
			reminder.hidden = True
			reminder.save()

	print "Donezo!"

if __name__ == "__main__":
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])

#!/usr/bin/python
import sys
import os

import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.models import User, Entry

logger = logging.getLogger(__name__)


def main(argv):
	print "Starting..."

	# UPDATE this list to whoever you want to send this to
	userList = User.objects.filter(product_id=0)

	for user in userList:
		reminders = Entry.objects.filter(creator=user, label="#reminders", remind_last_notified__isnull=False, hidden=False)[:10]

		for reminder in reminders:
			print "%s" % reminder.id
			#reminder.hidden = True
			#reminder.save()


if __name__ == "__main__":
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])

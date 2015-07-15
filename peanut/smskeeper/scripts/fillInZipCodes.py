#!/usr/bin/python
import sys
import os
import operator
import json

import logging

parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0], "..")

if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.db.models import Q

from smskeeper.models import User, Entry, Message
from smskeeper import keeper_constants, msg_util

logger = logging.getLogger(__name__)


def main(argv):
	print "Starting..."
	users = User.objects.filter(postal_code__isnull=True).exclude(state="stopped")

	for user in users:
		messages = Message.objects.filter(user=user, incoming=True).order_by('added')[:10]

		zipcode = None

		for message in messages:
			body = message.getBody()
			z = msg_util.getZipcode(body)
			if z:
				zipcode = z

		if zipcode:
			timezone = msg_util.timezoneForPostalCode(zipcode)

			if timezone:
				user.postal_code = zipcode
				user.save()

if __name__ == "__main__":
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])

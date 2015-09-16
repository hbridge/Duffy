#!/usr/bin/python
import sys
import os
import json

import logging

parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0], "..")

if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.models import Message
from smskeeper import keeper_constants

logger = logging.getLogger(__name__)



def main(argv):
	print "Starting..."

	classified_messages = Message.objects.filter(incoming=True).order_by('user')
	classified_messages = classified_messages.exclude(classification__isnull=True)
	classified_messages = classified_messages.exclude(classification__exact='')
	classified_messages = classified_messages.exclude(classification=keeper_constants.CLASS_NONE)

	f = open('workfile', 'w')
	for msg in classified_messages:
		msgData = json.loads(msg.msg_json)
		body = ''.join([i if ord(i) < 128 else ' ' for i in msgData["Body"]])

		f.write("%s\t%s\n" % (msg.classification, body))
		#print "%s\t%s\n" % (msg.classification, msgData["Body"])

	f.close()
	print "Donezo!"

if __name__ == "__main__":
	logging.basicConfig(filename='/mnt/log/massSMS.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])

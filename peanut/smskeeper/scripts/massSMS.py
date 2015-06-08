#!/usr/bin/python
# This Python file uses the following encoding: utf-8
import sys, os
import time, datetime
import pytz
import logging

parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0], "..")

if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.db.models import Count
from django.db.models import Q
from django.conf import settings

from smskeeper.sms_util import sendMsg
from smskeeper.models import User

logger = logging.getLogger(__name__)

def sendMassSMS(userIdList):
	userList = User.objects.filter(id__in=userIdList)

	for user in userList:
		msg = u"Hi %s! I'm trying to go from 🐣 to 🐓. Do you have any tips for me on how I can help you more? getkeeper.com/feedback.php"%(user.name)
		logger.debug("Sent msg to %s: %s"%(user.id, msg))
		sendMsg(user, msg, None, settings.KEEPER_NUMBER)


def main(argv):
	print "Starting..."

	# UPDATE this list to whoever you want to send this to
	userList = [1, 2]

	sendMassSMS(userList)
	print "Donezo!"

if __name__ == "__main__":
	logging.basicConfig(filename='/mnt/log/massSMS.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
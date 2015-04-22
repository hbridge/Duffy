from __future__ import absolute_import
import sys, os
import time, datetime
import logging
import pytz

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from peanut.celery import app

from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

from memfresh.models import User, FollowUp
from memfresh import utils

def getRecentEvents(user):
	pass

@app.task
def evalUserForFollowUp(userId):
	user = User.objects.get(id=userId)
	calService = utils.getService(user, "calendar")

	if not calService:
		return None

	event = utils.getMostCompletedRecentEvent(calService, datetime.timedelta(hours=4))

	if event:
		followUpIds = utils.getEventIdsWithFollowUps(user)
		if event["id"] not in followUpIds:
			utils.askForFollowUpForEvent(user, event)

@app.task
def evalAllUsersForFollowUp():
	for user in User.objects.all():
		evalUserForFollowUp(user.id)

@app.task
def analyzeCalendarEntries(user, entries):
	pass

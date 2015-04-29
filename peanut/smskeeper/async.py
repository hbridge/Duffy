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

from smskeeper.models import NoteEntry
from smskeeper import sms_util

@app.task
def processReminder(entryId):
	entry = NoteEntry.objects.get(id=entryId)

	msg = "Hi, friendly reminder to %s" % entry.text

	sms_util.sendMsg(entry.note.user, msg, None, entry.keeper_number)

	entry.reminded = True
	entry.save()

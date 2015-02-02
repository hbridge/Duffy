from __future__ import absolute_import
import sys, os
import time, datetime
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from common.models import User, ContactEntry, FriendConnection

from strand import notifications_util

from peanut.celery import app

from async import celery_helper

from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

@app.task
def sendRefreshFeedToUserIds(userIds):
	notifications_util.threadedSendNotifications(userIds)
	return len(userIds)


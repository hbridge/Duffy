from __future__ import absolute_import
import sys, os
import time, datetime
import logging

from django.dispatch import receiver
from django.db.models.signals import post_save

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from common.models import User, ContactEntry, FriendConnection, Action

from strand import notifications_util

from peanut.celery import app

from async import celery_helper

from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

@receiver(post_save, sender=Action)
def sendNotificationsUponActions(sender, **kwargs):
	action = kwargs.get('instance')

	users = list()

	if action.share_instance:
		users = list(action.share_instance.users.all())
		
	if action.user and action.user not in users:
		users.append(action.user)

	userIds = User.getIds(users)

	sendRefreshFeedToUserIds.delay(userIds)

@app.task
def sendRefreshFeedToUserIds(userIds):
	notifications_util.threadedSendNotifications(userIds)
	return len(userIds)


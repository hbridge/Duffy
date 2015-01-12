import datetime
import json
import logging
from threading import Thread

from django.db.models import Q
from django.dispatch import receiver
from django.db.models.signals import post_save

from peanut.settings import constants
from common.models import NotificationLog, DuffyNotification, Action, User, Strand, ShareInstance
from common.api_util import DuffyJsonEncoder
from strand import strands_util, swaps_util

from ios_notifications.models import APNService, Device
from twilio.rest import TwilioRestClient

logger = logging.getLogger(__name__)

"""
	Send a notification to the given user
	msg is the string
	msgType is from constants
	withSound is boolean, if it vibrates
	withVisual is if its silent (no visual)

	Returns a list of logEntries (NotificationLog)
"""
def sendNotification(user, msg, msgTypeId, customPayload, metadata = None):
	if metadata:
		metadata = json.dumps(metadata, cls=DuffyJsonEncoder)

	if user.device_token:
		if user.device_token == "TESTTOKEN":
			logEntry = NotificationLog.objects.create(user=user, device_token="", msg="", custom_payload="", result=constants.IOS_NOTIFICATIONS_RESULT_ERROR, msg_type=msgTypeId, metadata=metadata)
			return [logEntry]

		devices = Device.objects.select_related().filter(token=user.device_token)

		if len(devices) == 0:
			logger.warning("Was told to send a notification to user %s who has a device token but nothing in the Device table" % user.id)
			logEntry = NotificationLog.objects.create(user=user, device_token="", msg=msg, custom_payload=customPayload, result=constants.IOS_NOTIFICATIONS_RESULT_ERROR, msg_type=msgTypeId, metadata=metadata)
			return [logEntry]
		
		logEntries = list()	
		for device in devices:
			notification = DuffyNotification()
			notification.message = (msg[:100] + '...') if len(msg) > 100 else msg
			notification.service = device.service

			payload = constants.NOTIFICATIONS_CUSTOM_DICT[msgTypeId]

			if customPayload:
				payload.update(customPayload)
				
			notification.custom_payload = json.dumps(payload, cls=DuffyJsonEncoder)

			if constants.NOTIFICATIONS_SOUND_DICT[msgTypeId]:
				notification.sound = constants.NOTIFICATIONS_SOUND_DICT[msgTypeId]

			# Its a visual notification if we don't put this in.  If we put it in, then its silent
			if not constants.NOTIFICATIONS_VIZ_DICT[msgTypeId]:
				notification.message = ""
				notification.content_available = 1

			if "badge" in customPayload:
				notification.badge = customPayload["badge"]

			apns = APNService.objects.get(id=device.service_id)

			# This sends
			apns.push_notification_to_devices(notification, [device])

		# This is for logging
		logEntries.append(NotificationLog.objects.create(user=user, device_token=device.token, msg=msg, custom_payload=customPayload, result=constants.IOS_NOTIFICATIONS_RESULT_SENT, msg_type=msgTypeId, metadata=metadata))
		return logEntries
	else:
		logger.warning("Was told to send a notification to user %s who doesn't have a device token" % user.id)
		logEntry = NotificationLog.objects.create(user=user, device_token="", msg=msg, custom_payload=customPayload, result=constants.IOS_NOTIFICATIONS_RESULT_ERROR, msg_type=msgTypeId, metadata=metadata)

		return [logEntry]

def sendRefreshFeedToUsers(users):
	# First send to sockets
	for user in users:
		logger.debug("Sending refresh feed to user %s" % (user.id))
		logEntry = NotificationLog.objects.create(user=user, msg_type=constants.NOTIFICATIONS_SOCKET_REFRESH_FEED)

def sendSMS(phoneNumber, msg):
	twilioclient = TwilioRestClient(constants.TWILIO_ACCOUNT, constants.TWILIO_TOKEN)

	if not phoneNumber.startswith('+'):
		phoneNumber = "+1" + phoneNumber
		
	twilioclient.sms.messages.create(to=phoneNumber, from_=constants.TWILIO_PHONE_NUM, body=msg)

"""
	Create a dictionary per user_id on last notification time of NewPhoto notifications
"""
def getNotificationsForTypeById(notificationLogs, msgType, timeCutoff = None):
	notificationsById = dict()
	for notificationLog in notificationLogs:
		if notificationLog.msg_type == msgType:
			if (timeCutoff and notificationLog.added > timeCutoff) or (not timeCutoff):
				if notificationLog.user_id not in notificationsById:
					notificationsById[notificationLog.user_id] = list()
				notificationsById[notificationLog.user_id].append(notificationLog)

	return notificationsById

"""
	Create a dictionary per user_id on last notification time of NewPhoto notifications
"""
def getNotificationsForTypeByIds(notificationLogs, msgTypes, timeCutoff = None):
	notificationsById = dict()

	for msgType in msgTypes:
		notifications = getNotificationsForTypeById(notificationLogs, msgType, timeCutoff)
		for id, notes in notifications.iteritems():
			if id not in notificationsById:
				notificationsById[id] = list()
			notificationsById[id].extend(notes)

	return notificationsById

"""
	Return back notification logs within 30 seconds
"""
def getNotificationLogs(timeWithinCutoff):
	# Grap notification logs from last hour.  If a user isn't in here, then they weren't notified
	notificationLogs = NotificationLog.objects.filter(added__gt=timeWithinCutoff)
	return notificationLogs

"""
	Return back notification logs within 30 seconds
"""
def getNotificationLogsForType(timeWithinCutoff, msgType):
	# Grap notification logs from last hour.  If a user isn't in here, then they weren't notified
	notificationLogs = NotificationLog.objects.filter(msg_type=msgType).filter(added__gt=timeWithinCutoff).filter(Q(apns__in=[-2,-1,1]) | Q(result=constants.IOS_NOTIFICATIONS_RESULT_SENT) | Q(result=constants.IOS_NOTIFICATIONS_RESULT_ERROR))
	return notificationLogs

"""
	Sends out push notifications for badging
"""
def threadedSendNotifications(userIds):
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	logger = logging.getLogger(__name__)

	users = User.objects.filter(id__in=userIds)
	
	# This does only db writes so is fast.  This uses the socket server
	sendRefreshFeedToUsers(users)

	actionsByUserId = getActionsByUserId(users)
	
	# Next send through push notifications
	# This might take a while since we have to hit apple's api.  Ok since we're in a new thread.
	for user in users:
		customPayload = dict()
		count = 0

		if user.id in actionsByUserId:
			count += len(actionsByUserId[user.id])

		# now add the count of photos in Incoming (meaning unread photos)
		count += swaps_util.getIncomingBadgeCount(user)

		customPayload["badge"] = count #don't make this a string, as that puts quotes around the number and it won't work
		sendNotification(user, "", constants.NOTIFICATIONS_REFRESH_FEED, customPayload)


def getActionsByUserId(users):
	actionsByUserId = dict()
	shareInstances = ShareInstance.objects.prefetch_related('user').filter(users__in=User.getIds(users))

	sisById = dict()
	for si in shareInstances:
		sisById[si.id] = si

	actions = Action.objects.filter(Q(action_type=constants.ACTION_TYPE_FAVORITE) | Q(action_type=constants.ACTION_TYPE_COMMENT)).filter(share_instance_id__in=ShareInstance.getIds(shareInstances)).order_by("-added")[:40]

	for user in users:
		for action in actions:
			if (action.user_id != user.id and 
				user in sisById[action.share_instance_id].users.all() and
				action.added > user.last_actions_list_request_timestamp):

				if user.id not in actionsByUserId:
					actionsByUserId[user.id] = list()
				actionsByUserId[user.id].append(action)
	return actionsByUserId

@receiver(post_save, sender=Action)
def sendNotificationsUponActions(sender, **kwargs):
	action = kwargs.get('instance')

	users = list()

	if action.share_instance:
		users = list(action.share_instance.users.all())
		
	if action.user and action.user not in users:
		users.append(action.user)

	userIds = User.getIds(users)

	Thread(target=threadedSendNotifications, args=(userIds,)).start()





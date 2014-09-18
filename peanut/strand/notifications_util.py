import datetime
import json
import logging

from django.db.models import Q

from peanut.settings import constants
from common.models import NotificationLog, DuffyNotification
from common.api_util import DuffyJsonEncoder

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
			notification.message = msg
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

	# Next send through push notifications
	# TODO(Derek) Maybe put this back in if we don't want to use socket server
	#for user in users:
	#	sendNotification(user, "", constants.NOTIFICATIONS_REFRESH_FEED, dict())

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


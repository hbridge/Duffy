import datetime
import json
import logging

from peanut.settings import constants
from common.models import NotificationLog, DuffyNotification

from ios_notifications.models import APNService, Device
from twilio.rest import TwilioRestClient

logger = logging.getLogger(__name__)

"""
	Send a notification to the given user
	msg is the string
	msgType is from constants
	withSound is boolean, if it vibrates
	withVisual is if its silent (no visual)

"""
def sendNotification(user, msg, msgTypeId, customPayload):
	if user.device_token:
		if user.device_token == "TESTTOKEN":
			logEntry = NotificationLog.objects.create(user=user, device_token="", msg="", custom_payload="", apns=-1, msg_type=msgTypeId)
			return logEntry

		devices = Device.objects.select_related().filter(token=user.device_token)

		if len(devices) == 0:
			logger.warning("Was told to send a notification to user %s who has a device token but nothing in the Device table" % user.id)
			logEntry = NotificationLog.objects.create(user=user, device_token="", msg=msg, custom_payload=customPayload, apns=-2, msg_type=msgTypeId)
			return logEntry
			
		for device in devices:
			notification = DuffyNotification()
			notification.message = msg
			notification.service = device.service

			payload = constants.NOTIFICATIONS_CUSTOM_DICT[msgTypeId]

			if customPayload:
				payload.update(customPayload)
				
			notification.custom_payload = json.dumps(payload)

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
			logEntry = NotificationLog.objects.create(user=user, device_token=device.token, msg=msg, custom_payload=customPayload, apns=apns.id, msg_type=msgTypeId)
	else:
		logger.warning("Was told to send a notification to user %s who doesn't have a device token" % user.id)
		logEntry = NotificationLog.objects.create(user=user, device_token="", msg=msg, custom_payload=customPayload, apns=-1, msg_type=msgTypeId)

		return logEntry

def sendRefreshFeed(user):
	msgType = constants.NOTIFICATIONS_REFRESH_FEED

	sendNotification(user, "", msgType, dict())

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
			if timeCutoff and notificationLog.added > timeCutoff:
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
	notificationLogs = NotificationLog.objects.select_related().filter(added__gt=timeWithinCutoff)
	return notificationLogs
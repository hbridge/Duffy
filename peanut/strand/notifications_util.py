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
		devices = Device.objects.select_related().filter(token=user.device_token)	
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
			NotificationLog.objects.create(user=user, device_token=device.token, msg=msg, custom_payload=customPayload, apns=apns.id, msg_type=msgTypeId)
	else:
		logger.warning("Was told to send a notification to user %s who doesn't have a device token" % user)
	

def sendSMS(phoneNumber, msg):
	twilioclient = TwilioRestClient(constants.TWILIO_ACCOUNT, constants.TWILIO_TOKEN)

	if not phoneNumber.startswith('+'):
		phoneNumber = "+1" + phoneNumber
		
	twilioclient.sms.messages.create(to=phoneNumber, from_=constants.TWILIO_PHONE_NUM, body=msg)

"""
	Create a dictionary per user_id on last notification time of NewPhoto notifications
"""
def getNotificationsForTypeById(notificationLogs, msgType):
	notificationsById = dict()
	
	for notificationLog in notificationLogs:
		if notificationLog.msg_type == msgType:
			if notificationLog.user_id not in notificationsById:
				notificationsById[notificationLog.user_id] = list()
			notificationsById[notificationLog.user_id].append(notificationLog)

	return notificationsById

"""
	Return back notification logs within 30 seconds
"""
def getNotificationLogs(timeWithinSec=30):
	# Grap notification logs from last hour.  If a user isn't in here, then they weren't notified
	notificationLogs = NotificationLog.objects.select_related().filter(added__gt=datetime.datetime.utcnow()-datetime.timedelta(seconds=timeWithinSec))
	return notificationLogs
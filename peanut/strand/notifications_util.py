import datetime
import json
import logging

from peanut.settings import constants
from common.models import NotificationLog

from ios_notifications.models import APNService, Device, Notification
from twilio.rest import TwilioRestClient

logger = logging.getLogger(__name__)

def sendNotification(user, msg, msgType, customPayload=None):
	if user.device_token:
		devices = Device.objects.select_related().filter(token=user.device_token)	
		for device in devices:
			notification = Notification()
			notification.message = msg
			notification.service = device.service
			notification.custom_payload = json.dumps(customPayload)
			notification.sound = 'default'
			apns = APNService.objects.get(id=device.service_id)
			apns.push_notification_to_devices(notification, [device])
			NotificationLog.objects.create(user=user, device_token=device.token, msg=(getMessageWithCustomPayload(msg, customPayload)), apns=apns.id, msg_type=msgType)
	else:
		logger.warning("Was told to send a notification to user %s who doesn't have a device token" % user)
	
def getMessageWithCustomPayload(msg, customPayload = None):
	if customPayload:
		return msg + ' ' + json.dumps(customPayload)
	else:
		return msg


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
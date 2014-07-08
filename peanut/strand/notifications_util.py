import datetime
import json

from peanut.settings import constants
from common.models import NotificationLog

from ios_notifications.models import APNService, Device, Notification
from twilio.rest import TwilioRestClient

def sendNotification(user, msg, msgType, customPayload=None):
	devices = Device.objects.select_related().filter(token=user.device_token)	
	for device in devices:
		notification = Notification()
		notification.message = msg
		notification.service = device.service
		notification.custom_payload = json.dumps(customPayload)
		notification.sound = 'default'
		apns = APNService.objects.get(id=device.service_id)
		apns.push_notification_to_devices(notification, [device])
		NotificationLog.objects.create(user=user, device_token=device.token, msg=(msg+' ' + json.dumps(customPayload)), apns=apns.id, msg_type=msgType)

def sendSMS(phoneNumber, msg):
	twilioclient = TwilioRestClient(constants.TWILIO_ACCOUNT, constants.TWILIO_TOKEN)

	if not phoneNumber.startswith('+'):
		phoneNumber = "+1" + phoneNumber
		
	twilioclient.sms.messages.create(to=phoneNumber, from_=constants.TWILIO_PHONE_NUM, body=msg)
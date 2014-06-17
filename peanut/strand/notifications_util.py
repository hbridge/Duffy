import datetime

from peanut import settings

from common.models import NotificationLog
from ios_notifications.models import APNService, Device, Notification

def sendNotification(user, msg):
	devices = Device.objects.select_related().filter(token=user.device_token)	
	for device in devices:
		notification = Notification()
		notification.message = msg
		notification.service = device.service
		apns = APNService.objects.get(id=device.service_id)
		apns.push_notification_to_devices(notification, [device])
		NotificationLog.objects.create(user=user, device_token=device.token, msg=msg, apns=apns.id)
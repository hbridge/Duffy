import datetime
import json
import logging
from threading import Thread
import urllib2

from django.db.models import Q
from django.dispatch import receiver
from django.db.models.signals import post_save

from peanut.settings import constants
from common.models import NotificationLog, DuffyNotification, Action, User, Strand, ShareInstance
from common.api_util import DuffyJsonEncoder
from strand import strands_util, swaps_util

from ios_notifications.models import APNService, Device
from twilio.rest import TwilioRestClient
import plivo

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
			try:
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

				# If wake app bit is true, wake up the app
				if constants.NOTIFICATIONS_WAKE_APP_DICT[msgTypeId]:
					notification.content_available = 1

				if "badge" in customPayload:
					notification.badge = customPayload["badge"]

				apns = APNService.objects.get(id=device.service_id)

				# This sends
				apns.push_notification_to_devices(notification, [device])
			except:
				logger.debug("Barfed on sending %s to %s with device service_id: %s and full device object: %s" % (msg, user.id, device.service_id, device))

		# This is for logging
		logEntries.append(NotificationLog.objects.create(user=user, device_token=device.token, msg=msg, custom_payload=customPayload, result=constants.IOS_NOTIFICATIONS_RESULT_SENT, msg_type=msgTypeId, metadata=metadata))
		return logEntries
	else:
		logger.warning("Was told to send a notification to user %s who doesn't have a device token" % user.id)

		# check if this msgTypeId allows texting
		if constants.NOTIFICATIONS_SMS_DICT[msgTypeId]:
			logger.info("Sending txt instead %s" % user.id)
			if (not '555555' in str(user.phone_number)):
				msg = "Swap: " + msg + " " + constants.NOTIFICATIONS_SMS_URL_DICT[msgTypeId]

				if "mms_url" in customPayload:
					sendSMS(str(user.phone_number), msg, customPayload["mms_url"])
				else:
					sendSMS(str(user.phone_number), msg, None)

				logger.debug("SMS sent to %s: %s" % (user, msg))
			else:
				logger.debug("Nothing sent to %s: %s" % (user, msg))

			logEntry = NotificationLog.objects.create(user=user, device_token="", msg=msg, custom_payload=customPayload, result=constants.IOS_NOTIFICATIONS_RESULT_SMS_SENT_INSTEAD, msg_type=msgTypeId, metadata=metadata)
		else:
			logEntry = NotificationLog.objects.create(user=user, device_token="", msg=msg, custom_payload=customPayload, result=constants.IOS_NOTIFICATIONS_RESULT_ERROR, msg_type=msgTypeId, metadata=metadata)

		return [logEntry]

def sendRefreshFeedToUsers(users):
	# First send to sockets
	logEntryIdList = list()
	for user in users:
		logger.debug("Sending refresh feed to user %s" % (user.id))
		logEntry = NotificationLog.objects.create(user=user, msg_type=constants.NOTIFICATIONS_SOCKET_REFRESH_FEED)
		logEntryIdList.append(logEntry.id)

	param = 'ids=' + ','.join(str(x) for x in logEntryIdList)
	httpRefreshFeedServerUrl = constants.HTTP_SOCKET_SERVER + "?" + param

	logger.debug("Requesting URL:  %s" % httpRefreshFeedServerUrl)
	result = urllib2.urlopen(httpRefreshFeedServerUrl).read()


def sendSMS(phoneNumber, msg, mmsUrl):
	if phoneNumber.startswith('+91'):
		sendSMSThroughPlivo(phoneNumber, msg)
	else:
		sendSMSThroughTwilio(phoneNumber, msg, mmsUrl)

def sendSMSThroughTwilio(phoneNumber, msg, mediaUrl, fromNumber=constants.TWILIO_PHONE_NUM):
	twilioclient = TwilioRestClient(constants.TWILIO_ACCOUNT, constants.TWILIO_TOKEN)

	if mediaUrl:
		twilioclient.messages.create(to=phoneNumber, from_=fromNumber, body=msg, media_url=mediaUrl)
	else:
		twilioclient.messages.create(to=phoneNumber, from_=fromNumber, body=msg)

def sendSMSThroughPlivo(phoneNumber, msg):

	messageParams = {
	  'src':constants.PLIVO_PHONE_NUM,
	  'dst':phoneNumber,
	  'text':msg,
	}
	p = plivo.RestAPI(constants.PLIVO_AUTH_ID, constants.PLIVO_AUTH_TOKEN)
	logger.info(p.send_message(messageParams))

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

	actionsCountByUserId = getUnreadActionsListCountByUserId(users)

	# Next send through push notifications
	# This might take a while since we have to hit apple's api.  Ok since we're in a new thread.
	for user in users:
		customPayload = dict()
		count = 0

		if user.id in actionsCountByUserId:
			count += actionsCountByUserId[user.id]

		if count > 0:
			customPayload["badge"] = count #don't make this a string, as that puts quotes around the number and it won't work
			sendNotification(user, "", constants.NOTIFICATIONS_UPDATE_BADGE, customPayload)


def getUnreadActionsListCountByUserId(users):
	actionsByUserId = dict()

	for user in users:
		actionsData = swaps_util.getActionsList(user)
		actionCount = swaps_util.getActionsListUnreadCount(user, actionsData)
		actionsByUserId[user.id] = actionCount

	return actionsByUserId


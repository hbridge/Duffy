PIPELINE_LOCAL_BASE_PATH = "/var/duffy/user_data/"
PIPELINE_REMOTE_HOST = 'duffy@titanblack.duffyapp.com'
PIPELINE_REMOTE_PATH = '/home/duffy/pipeline/staging'

THUMBNAIL_SIZE = 156

STATE_NEW = 0
STATE_COPIED = 1
STATE_CLASSIFIED = 2

DEFAULT_CLUSTER_THRESHOLD = 80
DEFAULT_DUP_THRESHOLD = 40
DEFAULT_MINUTES_TO_CLUSTER = 5

# iOS Notifications

IOS_NOTIFICATIONS_AUTHENTICATION = 'AuthNone'
IOS_NOTIFICATIONS_DEV_APNS_HOSTNAME = 'gateway.sandbox.push.apple.com'
IOS_NOTIFICATIONS_DEV_APNS_SERVICENAME = 'StrandDev'

IOS_NOTIFICATIONS_PROD_APNS_HOSTNAME = 'gateway.push.apple.com'
IOS_NOTIFICATIONS_PROD_APNS_SERVICENAME = 'StrandProd'

IOS_NOTIFICATIONS_DEV_APNS_ID = 1
IOS_NOTIFICATIONS_PROD_APNS_ID = 2
IOS_NOTIFICATIONS_DEREK_DEV_APNS_ID = 3
IOS_NOTIFICATIONS_ENTERPRISE_PROD_APNS_ID = 4
IOS_NOTIFICATIONS_ENTERPRISE_DEV_APNS_ID = 5

NOTIFICATIONS_NEW_PHOTO_ID = 1
NOTIFICATIONS_JOIN_STRAND_ID = 2
NOTIFICATIONS_PHOTO_FAVORITED_ID = 3

NOTIFICATIONS_APP_VIEW_CAMERA = 0
NOTIFICATIONS_APP_VIEW_GALLERY = 1

TWILIO_ACCOUNT = "ACf7272766cd6e51024750c3a1395a6f2f"
TWILIO_TOKEN = "63eb729d07ec8980d5267cb6b715e06f"
TWILIO_PHONE_NUM = "16506662114"

DEV_PHONE_NUMBERS = ["+16508158274", "+19172827255", "+16505759014"]

# 3 hours
TIME_WITHIN_MINUTES_FOR_NEIGHBORING = 3 * 60
DISTANCE_WITHIN_METERS_FOR_NEIGHBORING = 250
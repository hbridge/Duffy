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

IOS_NOTIFICATIONS_RESULT_ERROR = 0
IOS_NOTIFICATIONS_RESULT_SENT = 1
IOS_NOTIFICATIONS_RESULT_NOT_SENT = 2

NOTIFICATIONS_NEW_PHOTO_ID = 1
NOTIFICATIONS_JOIN_STRAND_ID = 2
NOTIFICATIONS_PHOTO_FAVORITED_ID = 3
NOTIFICATIONS_FETCH_GPS_ID = 4
NOTIFICATIONS_RAW_FIRESTARTER_ID = 5
NOTIFICATIONS_PHOTO_FIRESTARTER_ID = 6
NOTIFICATIONS_REFRESH_FEED = 7
NOTIFICATIONS_SOCKET_REFRESH_FEED = 8
NOTIFICATIONS_INVITED_TO_STRAND = 9
NOTIFICATIONS_ACCEPTED_INVITE = 10

# This is really 1-6
NOTIFICATIONS_ANY = range(1,7)

NOTIFICATIONS_SOUND_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : 'default',
	NOTIFICATIONS_JOIN_STRAND_ID : 'default',
	NOTIFICATIONS_PHOTO_FAVORITED_ID : 'default',
	NOTIFICATIONS_FETCH_GPS_ID : None,
	NOTIFICATIONS_RAW_FIRESTARTER_ID : None,
	NOTIFICATIONS_PHOTO_FIRESTARTER_ID : 'default',
	NOTIFICATIONS_REFRESH_FEED : None,
	NOTIFICATIONS_INVITED_TO_STRAND : 'default',
	NOTIFICATIONS_ACCEPTED_INVITE : 'default',
}

NOTIFICATIONS_VIZ_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : True,
	NOTIFICATIONS_JOIN_STRAND_ID : True,
	NOTIFICATIONS_PHOTO_FAVORITED_ID : True,
	NOTIFICATIONS_FETCH_GPS_ID : False,
	NOTIFICATIONS_RAW_FIRESTARTER_ID : True,
	NOTIFICATIONS_PHOTO_FIRESTARTER_ID : True,
	NOTIFICATIONS_REFRESH_FEED : False,
	NOTIFICATIONS_INVITED_TO_STRAND : True,
	NOTIFICATIONS_ACCEPTED_INVITE : True,
}

NOTIFICATIONS_CUSTOM_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : {'type': NOTIFICATIONS_NEW_PHOTO_ID, 'view': 1},
	NOTIFICATIONS_JOIN_STRAND_ID : {'type': NOTIFICATIONS_JOIN_STRAND_ID, 'view': 0},
	NOTIFICATIONS_PHOTO_FAVORITED_ID : {'type': NOTIFICATIONS_PHOTO_FAVORITED_ID, 'view': 0},
	NOTIFICATIONS_FETCH_GPS_ID : {'type': NOTIFICATIONS_FETCH_GPS_ID, 'fgps': 1},
	NOTIFICATIONS_RAW_FIRESTARTER_ID : {'type': NOTIFICATIONS_RAW_FIRESTARTER_ID}, 
	NOTIFICATIONS_PHOTO_FIRESTARTER_ID : {'type': NOTIFICATIONS_PHOTO_FIRESTARTER_ID},
	NOTIFICATIONS_REFRESH_FEED : {'type': NOTIFICATIONS_REFRESH_FEED, 'ff': 1},
	NOTIFICATIONS_INVITED_TO_STRAND : {'type': NOTIFICATIONS_INVITED_TO_STRAND},
	NOTIFICATIONS_ACCEPTED_INVITE : {'type': NOTIFICATIONS_ACCEPTED_INVITE},
}

NOTIFICATIONS_APP_VIEW_CAMERA = 0
NOTIFICATIONS_APP_VIEW_GALLERY = 1

TWILIO_ACCOUNT = "ACf7272766cd6e51024750c3a1395a6f2f"
TWILIO_TOKEN = "63eb729d07ec8980d5267cb6b715e06f"
TWILIO_PHONE_NUM = "16506662114"

DEV_PHONE_NUMBERS = ["+16508158274", "+19172827255", "+16505759014"]

# 3 hours
TIME_WITHIN_MINUTES_FOR_NEIGHBORING = 3 * 60
DISTANCE_WITHIN_METERS_FOR_NEIGHBORING = 175

# links for inviting
INVITE_LINK_ENTERPRISE = 'bit.ly/1noDnx2' # bit.ly/strand-beta also works
INVITE_LINK_APP_STORE = 'bit.ly/strand-appstore'

FEED_OBJECT_TYPE_STRAND = 'section' # will be strand
FEED_OBJECT_TYPE_INVITE_STRAND = 'invite_strand'
FEED_OBJECT_TYPE_STRAND_POST = 'strand_post'
FEED_OBJECT_TYPE_SUGGESTED_PHOTOS = 'suggested_photos'


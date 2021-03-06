
import datetime

PIPELINE_LOCAL_BASE_PATH = "/mnt/user_data/"
PIPELINE_REMOTE_HOST = 'duffy@titanblack.duffyapp.com'
PIPELINE_REMOTE_PATH = '/home/duffy/pipeline/staging'

# HttpSocketServer info
HTTP_SOCKET_SERVER = 'http://0.0.0.0:7999/'

THUMBNAIL_SIZE = 156

STATE_NEW = 0
STATE_COPIED = 1
STATE_CLASSIFIED = 2

DEFAULT_CLUSTER_THRESHOLD = 80
DEFAULT_DUP_THRESHOLD = 40
DEFAULT_MINUTES_TO_CLUSTER = 5

# links for inviting
INVITE_LINK_ENTERPRISE = 'bit.ly/get-swap-app' # bit.ly/strand-beta also works
INVITE_LINK_APP_STORE = 'bit.ly/swap-appstore'
APP_SHORTLINK_EXISTING_USER = 'bit.ly/openswap'
APP_SHORTLINK_NEW_USER = 'bit.ly/get-swap-app'

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
IOS_NOTIFICATIONS_RESULT_SMS_SENT_INSTEAD = 3

NOTIFICATIONS_NEW_PHOTO_ID = 1
NOTIFICATIONS_JOIN_STRAND_ID = 2 # Not used
NOTIFICATIONS_PHOTO_FAVORITED_ID = 3
NOTIFICATIONS_FETCH_GPS_ID = 4
NOTIFICATIONS_UNSEEN_PHOTOS_FS = 5 # Used to perodically indicate that you have something to do in the app
NOTIFICATIONS_ACTIVATE_ACCOUNT_FS = 6 # Used to activate users who are invited but never downloaded app
NOTIFICATIONS_UPDATE_BADGE = 7
NOTIFICATIONS_SOCKET_REFRESH_FEED = 8
NOTIFICATIONS_INVITED_TO_STRAND = 9 # Not used
NOTIFICATIONS_ACCEPTED_INVITE = 10 # Not used
NOTIFICATIONS_RETRO_FIRESTARTER = 11 # Not used
NOTIFICATIONS_UNACCEPTED_INVITE_FS = 12 # Not used
NOTIFICATIONS_PHOTO_COMMENT = 13
NOTIFICATIONS_NEW_SUGGESTION = 14
NOTIFICATIONS_ADD_FRIEND = 15
NOTIFICATIONS_REQUEST_PHOTOS_SUGGESTION = 16 # lets a user know that there are photos she can request
NOTIFICATIONS_PHOTOS_REQUESTED = 17 # lets a user know that someone requested photos

# This is really 1-6
NOTIFICATIONS_ANY = range(1,7)

NOTIFICATIONS_SOUND_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : 'default',
	NOTIFICATIONS_JOIN_STRAND_ID : 'default',
	NOTIFICATIONS_PHOTO_FAVORITED_ID : 'default',
	NOTIFICATIONS_FETCH_GPS_ID : None,
	NOTIFICATIONS_UNSEEN_PHOTOS_FS : None,
	NOTIFICATIONS_ACTIVATE_ACCOUNT_FS : None,
	NOTIFICATIONS_UPDATE_BADGE : None,
	NOTIFICATIONS_INVITED_TO_STRAND : 'default',
	NOTIFICATIONS_ACCEPTED_INVITE : 'default',
	NOTIFICATIONS_RETRO_FIRESTARTER : 'default',
	NOTIFICATIONS_UNACCEPTED_INVITE_FS : None,
	NOTIFICATIONS_PHOTO_COMMENT : 'default',
	NOTIFICATIONS_NEW_SUGGESTION : None,
	NOTIFICATIONS_ADD_FRIEND : 'default',
	NOTIFICATIONS_REQUEST_PHOTOS_SUGGESTION : None,
	NOTIFICATIONS_PHOTOS_REQUESTED : 'default',
}

NOTIFICATIONS_VIZ_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : True,
	NOTIFICATIONS_JOIN_STRAND_ID : True,
	NOTIFICATIONS_PHOTO_FAVORITED_ID : True,
	NOTIFICATIONS_FETCH_GPS_ID : False,
	NOTIFICATIONS_UNSEEN_PHOTOS_FS : True,
	NOTIFICATIONS_ACTIVATE_ACCOUNT_FS : True,
	NOTIFICATIONS_UPDATE_BADGE : False,
	NOTIFICATIONS_INVITED_TO_STRAND : True,
	NOTIFICATIONS_ACCEPTED_INVITE : True,
	NOTIFICATIONS_RETRO_FIRESTARTER : True,
	NOTIFICATIONS_UNACCEPTED_INVITE_FS : True,
	NOTIFICATIONS_PHOTO_COMMENT : True,
	NOTIFICATIONS_NEW_SUGGESTION : True,
	NOTIFICATIONS_ADD_FRIEND : True,
	NOTIFICATIONS_REQUEST_PHOTOS_SUGGESTION : True,
	NOTIFICATIONS_PHOTOS_REQUESTED : True,
}

NOTIFICATIONS_WAKE_APP_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : False,
	NOTIFICATIONS_JOIN_STRAND_ID : False,
	NOTIFICATIONS_PHOTO_FAVORITED_ID : False,
	NOTIFICATIONS_FETCH_GPS_ID : True,
	NOTIFICATIONS_UNSEEN_PHOTOS_FS : False,
	NOTIFICATIONS_ACTIVATE_ACCOUNT_FS : False,
	NOTIFICATIONS_UPDATE_BADGE : False,
	NOTIFICATIONS_INVITED_TO_STRAND : False,
	NOTIFICATIONS_ACCEPTED_INVITE : False,
	NOTIFICATIONS_RETRO_FIRESTARTER : False,
	NOTIFICATIONS_UNACCEPTED_INVITE_FS : False,
	NOTIFICATIONS_PHOTO_COMMENT : False,
	NOTIFICATIONS_NEW_SUGGESTION : False,
	NOTIFICATIONS_ADD_FRIEND : False,
	NOTIFICATIONS_REQUEST_PHOTOS_SUGGESTION : False,
	NOTIFICATIONS_PHOTOS_REQUESTED : False,
}

NOTIFICATIONS_CUSTOM_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : {'type': NOTIFICATIONS_NEW_PHOTO_ID, 'view': 1},
	NOTIFICATIONS_JOIN_STRAND_ID : {'type': NOTIFICATIONS_JOIN_STRAND_ID, 'view': 0},
	NOTIFICATIONS_PHOTO_FAVORITED_ID : {'type': NOTIFICATIONS_PHOTO_FAVORITED_ID, 'view': 0},
	NOTIFICATIONS_FETCH_GPS_ID : {'type': NOTIFICATIONS_FETCH_GPS_ID, 'fgps': 1},
	NOTIFICATIONS_UNSEEN_PHOTOS_FS : {'type': NOTIFICATIONS_UNSEEN_PHOTOS_FS},
	NOTIFICATIONS_ACTIVATE_ACCOUNT_FS : {'type': NOTIFICATIONS_ACTIVATE_ACCOUNT_FS},
	NOTIFICATIONS_UPDATE_BADGE : {'type': NOTIFICATIONS_UPDATE_BADGE},
	NOTIFICATIONS_INVITED_TO_STRAND : {'type': NOTIFICATIONS_INVITED_TO_STRAND},
	NOTIFICATIONS_ACCEPTED_INVITE : {'type': NOTIFICATIONS_ACCEPTED_INVITE},
	NOTIFICATIONS_RETRO_FIRESTARTER : {'type': NOTIFICATIONS_RETRO_FIRESTARTER},
	NOTIFICATIONS_UNACCEPTED_INVITE_FS : {'type': NOTIFICATIONS_UNACCEPTED_INVITE_FS},
	NOTIFICATIONS_PHOTO_COMMENT : {'type': NOTIFICATIONS_PHOTO_COMMENT},
	NOTIFICATIONS_NEW_SUGGESTION : {'type': NOTIFICATIONS_NEW_SUGGESTION},
	NOTIFICATIONS_ADD_FRIEND : {'type': NOTIFICATIONS_ADD_FRIEND},
	NOTIFICATIONS_REQUEST_PHOTOS_SUGGESTION : {'type': NOTIFICATIONS_REQUEST_PHOTOS_SUGGESTION},
	NOTIFICATIONS_PHOTOS_REQUESTED : {'type': NOTIFICATIONS_PHOTOS_REQUESTED},
}

# Tracks whether to send out SMS if device_token not available
NOTIFICATIONS_SMS_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : False,
	NOTIFICATIONS_JOIN_STRAND_ID : False,
	NOTIFICATIONS_PHOTO_FAVORITED_ID : False,
	NOTIFICATIONS_FETCH_GPS_ID : False,
	NOTIFICATIONS_UNSEEN_PHOTOS_FS : True,
	NOTIFICATIONS_ACTIVATE_ACCOUNT_FS : True,
	NOTIFICATIONS_UPDATE_BADGE : False,
	NOTIFICATIONS_INVITED_TO_STRAND : False,
	NOTIFICATIONS_ACCEPTED_INVITE : False,
	NOTIFICATIONS_RETRO_FIRESTARTER : False,
	NOTIFICATIONS_UNACCEPTED_INVITE_FS : False,
	NOTIFICATIONS_PHOTO_COMMENT : True,
	NOTIFICATIONS_NEW_SUGGESTION : False,
	NOTIFICATIONS_ADD_FRIEND : False,
	NOTIFICATIONS_REQUEST_PHOTOS_SUGGESTION : False,
	NOTIFICATIONS_PHOTOS_REQUESTED : False,
}

NOTIFICATIONS_SMS_URL_DICT = {
	NOTIFICATIONS_NEW_PHOTO_ID : None,
	NOTIFICATIONS_JOIN_STRAND_ID : None,
	NOTIFICATIONS_PHOTO_FAVORITED_ID : None,
	NOTIFICATIONS_FETCH_GPS_ID : None,
	NOTIFICATIONS_UNSEEN_PHOTOS_FS : APP_SHORTLINK_EXISTING_USER,
	NOTIFICATIONS_ACTIVATE_ACCOUNT_FS : APP_SHORTLINK_NEW_USER,
	NOTIFICATIONS_UPDATE_BADGE : None,
	NOTIFICATIONS_INVITED_TO_STRAND : None,
	NOTIFICATIONS_ACCEPTED_INVITE : None,
	NOTIFICATIONS_RETRO_FIRESTARTER : None,
	NOTIFICATIONS_UNACCEPTED_INVITE_FS : None,
	NOTIFICATIONS_PHOTO_COMMENT : APP_SHORTLINK_EXISTING_USER,
	NOTIFICATIONS_NEW_SUGGESTION : None,
	NOTIFICATIONS_ADD_FRIEND : None,
	NOTIFICATIONS_REQUEST_PHOTOS_SUGGESTION : None,
	NOTIFICATIONS_PHOTOS_REQUESTED : None,
}

# All notification-related time intervals
NOTIFICATIONS_NEW_PHOTO_WAIT_INTERVAL_SECS = 60 # Waits this long before sending another NEW_PHOTO suggestion to same user
NOTIFICATIONS_NEW_SUGGESTION_INTERVAL_SECS = 600 # Waits this long before sending a suggestion to same user
NOTIFICATIONS_GPS_FROM_FRIEND_INTERVAL_MINS = 10 # Waits this long before repinging phones for new location
NOTIFICATIONS_ACTIVATE_ACCOUNT_FS_INTERVAL_DAYS= 7 # Waits this long before resending this notifications
NOTIFICATIONS_UNSEEN_PHOTOS_FS_INTERVAL_DAYS= 7

# All notification-related grace periods
NOTIFICATIONS_ACTIVATE_ACCOUNT_FS_GRACE_PERIOD_DAYS = 1 # Give users at least this long before reminding them

# For SMSing
TWILIO_ACCOUNT = "ACf7272766cd6e51024750c3a1395a6f2f"
TWILIO_TOKEN = "63eb729d07ec8980d5267cb6b715e06f"
TWILIO_PHONE_NUM = "16506662114"
TWILIO_MEMFRESH_PHONE_NUM = "3144037026"
TWILIO_SMSKEEPER_PHONE_NUM = "+14792026561"

# TODO(Derek): Migrate use of this over to keeper_constants
SMSKEEPER_TEST_NUM = "test"
SMSKEEPER_CLI_NUM = "cli"

# for SMSing to India (Twilio gets blocked in India often)
PLIVO_AUTH_ID = "MANWVIM2VMNDRJNDRMN2"
PLIVO_AUTH_TOKEN = "ZmVhNzI0ZDY2ZTFjNGNhNGUyOTg0OWVlZDAzMzdh"
PLIVO_PHONE_NUM = "14157631292"

DEV_PHONE_NUMBERS = ["+16508158274", "+19172827255", "+16505759014"]

WEBSITE_REGISTRATION_FILE = "/mnt/log/website-registration.csv"

# 3 hours
TIME_WITHIN_MINUTES_FOR_NEIGHBORING = 3 * 60
MINUTES_FOR_NOLOC_NEIGHBORING = 15

DISTANCE_WITHIN_METERS_FOR_ROUGH_NEIGHBORING = 750
DISTANCE_WITHIN_METERS_FOR_FINE_NEIGHBORING = 400

TIMEDELTA_FOR_STRANDING = datetime.timedelta(hours=3)

FEED_OBJECT_TYPE_STRAND = 'section'  # will be strand
FEED_OBJECT_TYPE_INVITE_STRAND = 'invite_strand'
FEED_OBJECT_TYPE_STRAND_POST = 'strand_post'
FEED_OBJECT_TYPE_STRAND_POSTS = 'strand_posts'
FEED_OBJECT_TYPE_LIKE_ACTION = 'like_action'
FEED_OBJECT_TYPE_SUGGESTED_PHOTOS = 'suggested_photos'
FEED_OBJECT_TYPE_STRAND_JOIN = 'strand_join'
FEED_OBJECT_TYPE_FRIENDS_LIST = 'people_list'
FEED_OBJECT_TYPE_SWAP_SUGGESTION = 'section'
FEED_OBJECT_TYPE_RELATIONSHIP = 'relationship'
FEED_OBJECT_TYPE_RELATIONSHIP_FRIEND = 'friend'
FEED_OBJECT_TYPE_RELATIONSHIP_USER = 'connection'
FEED_OBJECT_TYPE_RELATIONSHIP_REVERSE_FRIEND = 'reverse_friend'
FEED_OBJECT_TYPE_RELATIONSHIP_FORWARD_FRIEND = 'friend'

ACTION_TYPE_FAVORITE = 0
ACTION_TYPE_CREATE_STRAND = 1
ACTION_TYPE_SHARED_PHOTOS = 2
ACTION_TYPE_JOIN_STRAND = 3
ACTION_TYPE_COMMENT = 4
ACTION_TYPE_PHOTO_EVALUATED = 5
ACTION_TYPE_SUGGESTION = 6
ACTION_TYPE_ADD_FRIEND = 7
ACTION_TYPE_REQUEST_PHOTOS_SUGGESTION = 8
ACTION_TYPE_PHOTOS_REQUESTED = 9



from peanut.settings.base import *

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = False

# Used to support utf8 4 byte encoding in mysql.  Don't ask
# http://stackoverflow.com/questions/21517358/django-mysql-unknown-encoding-utf8mb4
import codecs
codecs.register(lambda name: codecs.lookup('utf8') if name == 'utf8mb4' else None)

DATABASES = {
	'default': {
		'ENGINE': 'django.contrib.gis.db.backends.mysql',
		'NAME': 'duffy',
		'USER': 'djangouser',
		'PASSWORD': 'djangopass',
		'HOST': 'ec2-54-164-29-216.compute-1.amazonaws.com',   # Or an IP Address that your DB is hosted on
		'PORT': '3306',
		'OPTIONS': {'charset': 'utf8mb4'},
	}
}

# SECURITY WARNING: keep the secret key used in production secret!
# TODO(Derek): move this out https://docs.djangoproject.com/en/1.6/howto/deployment/checklist/
SECRET_KEY = 'f(*vzc)x9!1-5nisajkfl3kjlflalsk!7)x9#x@&n2s=-)vb'

DEFAULT_FROM_EMAIL = 'server-errors@duffytech.co'

EMAIL_HOST = 'email-smtp.us-east-1.amazonaws.com'
EMAIL_PORT = 587
EMAIL_HOST_USER = 'AKIAJHHJPIGXPBWBGSKQ'
EMAIL_HOST_PASSWORD = 'AiAvYbMDxI7DbOlS9wWrsvbyVuykMNwIMnPkefsFH++O'
EMAIL_USE_TLS = True

SERVER_EMAIL = 'prod@duffyapp.com'

ADMINS = None
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "prod.strand.duffyapp.com", "my.getkeeper.com"]

# S3 Prod server settings
AWS_STORAGE_BUCKET_NAME = 'strand-prod'
AWS_IMAGE_HOST = "https://s3-external-1.amazonaws.com/" + AWS_STORAGE_BUCKET_NAME

class CELERY_CONFIG(BASE_CELERY_CONFIG):
	CELERY_SEND_TASK_ERROR_EMAILS = True
	ADMINS = [
		('Admins', 'server-errors@duffytech.co'),
	]
	BROKER_URL = "amqp://duffy:du44y@172.31.21.173:5672/swap"

KEEPER_NUMBER = "+14792026561"

# Don't forget to update keeper_constants.py PROD_PHONE_NUMBERS
KEEPER_NUMBER_DICT = {
	0: "+14792026561",
	1: "+14792086270",
	2: "3584573970819@s.whatsapp.net",
	3: "+19284851665",
	4: "+16462332164",
	5: "GetKeeperBot@telegram.me",
}

WHATSAPP_CREDENTIALS = ("3584573970819", "YtxpW7n5lMfJBZFSyANUbceCr1o=")
WHATSAPP_SMS_URL = "http://prod.strand.duffyapp.com/smskeeper/incoming_sms"
WHATSAPP_PRESENCE_NAME = u"\U0001F64B Keeper"

SLACK_LOGGING_URL = "https://hooks.slack.com/services/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"
USER_HISTORY_PATH = "http://prod.strand.duffyapp.com/smskeeper/history?user_id="

MIXPANEL_TOKEN = "165ffa12b4eac14005ec6d97872a9c63"
# commenting out since they're now invalid
#ZENDESK_URL = 'https://duffy.zendesk.com'
#ZENDESK_TOKEN = 'kkOHt9PAYkNz3ZBFluI1oCqx2U1jWdE6Q8SV57wo'

USE_CACHE = False

TELEGRAM_BOT_NAME = 'GetKeeperBot'
TELEGRAM_TOKEN = '132839906:AAFBxbdGZmzqmkWOiSJQLO74f1i0gFzRARM'

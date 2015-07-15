import sys
import logging

from peanut.settings.base import *

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

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
		'HOST': 'localhost',   # Or an IP Address that your DB is hosted on
		'PORT': '3306',
		'OPTIONS': {'charset': 'utf8mb4'},
	}
}

class DisableMigrations(object):

    def __contains__(self, item):
        return True

    def __getitem__(self, item):
        return "notmigrations"


# Configuration for speeding up tests.
if 'test' in sys.argv:
	DATABASES['default'] = {'ENGINE': 'django.db.backends.sqlite3'}
	logging.disable(logging.CRITICAL)

	CELERY_ALWAYS_EAGER = True
	CELERY_EAGER_PROPAGATES_EXCEPTIONS = True
	BROKER_BACKEND = 'memory'

	MIGRATION_MODULES = DisableMigrations()

	PASSWORD_HASHERS = (
		'django.contrib.auth.hashers.MD5PasswordHasher',
	)

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'f(*vzc)x9!1-5nis+uinolh=$*&#z@&2n!7)x9#x@&n2s=-)vb'


STATIC_ROOT = ''  # uncomment for static files for dev servers

# Additional locations of static files
STATICFILES_DIRS = (
	# Put strings here, like "/home/html/static" or "C:/www/django/static".
	# Always use forward slashes, even on Windows.
	# Don't forget to use absolute paths, not relative paths.
	'/home/ubuntu/dev/Duffy/peanut/static',
)

DEFAULT_FROM_EMAIL = 'swap-stats@duffytech.co'

EMAIL_HOST = 'email-smtp.us-east-1.amazonaws.com'
EMAIL_PORT = 587
EMAIL_HOST_USER = 'AKIAJHHJPIGXPBWBGSKQ'
EMAIL_HOST_PASSWORD = 'AiAvYbMDxI7DbOlS9wWrsvbyVuykMNwIMnPkefsFH++O'
EMAIL_USE_TLS = True

SERVER_EMAIL = 'dev@duffyapp.com'

ADMINS = None

ALLOWED_HOSTS = ["localhost", "127.0.0.1", "prod.strand.duffyapp.com", "dev.duffyapp.com"]

# S3 Dev server settings
AWS_STORAGE_BUCKET_NAME = 'strand-dev'
AWS_IMAGE_HOST = "https://s3-external-1.amazonaws.com/" + AWS_STORAGE_BUCKET_NAME

CELERYD_HIJACK_ROOT_LOGGER = False


class CELERY_CONFIG(BASE_CELERY_CONFIG):
	BROKER_URL = "amqp://duffy:du44y@dev.duffyapp.com:5672/swap"

KEEPER_NUMBER = "+18452088586"

# Keeper number by product id
KEEPER_NUMBER_DICT = {0: "+18452088586", 1: "+18452088586", 2: "3584573970584@s.whatsapp.net"}
WHATSAPP_CREDENTIALS = ("3584573970584", "2Vqf6AGTedRERwMVm3WdnU0DCbs=")
WHATSAPP_SMS_URL = "http://dev.duffyapp.com/smskeeper/incoming_sms"

MIXPANEL_TOKEN = "d309a366da36d3f897ad2772390d1679"

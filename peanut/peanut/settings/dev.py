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

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'f(*vzc)x9!1-5nis+uinolh=$*&#z@&2n!7)x9#x@&n2s=-)vb'


STATIC_ROOT = '' # uncomment for static files for dev servers

# Additional locations of static files
STATICFILES_DIRS = (
	# Put strings here, like "/home/html/static" or "C:/www/django/static".
	# Always use forward slashes, even on Windows.
	# Don't forget to use absolute paths, not relative paths.
   '/home/aseem/repos/Duffy/peanut/static',
)

DEFAULT_FROM_EMAIL = 'swap-stats@duffytech.co'

EMAIL_HOST = 'email-smtp.us-east-1.amazonaws.com'
EMAIL_PORT = 587
EMAIL_HOST_USER = 'AKIAJHHJPIGXPBWBGSKQ'
EMAIL_HOST_PASSWORD = 'AiAvYbMDxI7DbOlS9wWrsvbyVuykMNwIMnPkefsFH++O'
EMAIL_USE_TLS = True

SERVER_EMAIL = 'dev@duffyapp.com'

ADMINS = (
	('Admins', 'server-errors@duffytech.co'),
)

ALLOWED_HOSTS = ["localhost", "127.0.0.1", "prod.strand.duffyapp.com", "dev.duffyapp.com"]

#S3 Dev server settings
AWS_STORAGE_BUCKET_NAME = 'strand-dev'

CELERYD_HIJACK_ROOT_LOGGER = False

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
		'HOST': 'ec2-54-88-19-123.compute-1.amazonaws.com',   # Or an IP Address that your DB is hosted on
		'PORT': '3306',
		'OPTIONS': {'charset': 'utf8mb4'},
	}
}

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'f(*vzc)x9!1-5nisajkfl3kjlflalsk!7)x9#x@&n2s=-)vb'


# settings.py
LOGGING = {
	'version': 1,
	'disable_existing_loggers': False,
	'formatters': {
		'verbose': {
			'format' : "[%(asctime)s] %(levelname)s [%(name)s:%(lineno)s] %(message)s",
			'datefmt' : "%d/%b/%Y %H:%M:%S"
		},
		'simple': {
			'format': '%(asctime)s %(levelname)s %(message)s'
		},
	},
	'handlers': {
		'djangofile': {
			'level': 'INFO',
			'class':'logging.handlers.RotatingFileHandler',
			'filename': '/home/ubuntu/logs/duffy-all.log',
			'formatter': 'verbose'
		},
		'djangoerror': {
			'level': 'ERROR',
			'class':'logging.handlers.RotatingFileHandler',
			'filename': '/home/ubuntu/logs/duffy-error.log',
			'formatter': 'verbose'
		},
		'duffyfile': {
			'level': 'DEBUG',
			'class':'logging.handlers.RotatingFileHandler',
			'filename': '/home/ubuntu/logs/duffy-photos.log',
			'formatter': 'verbose'
		},
		'mail_admins': {
			'level': 'ERROR',
			'class': 'django.utils.log.AdminEmailHandler',
		},
		'celery': {
			'level': 'DEBUG',
			'class': 'logging.handlers.RotatingFileHandler',
			'filename': '/var/log/duffy/celery.log',
			'formatter': 'simple',
			'maxBytes': 1024 * 1024 * 100,  # 100 mb
		},
		'two_fishes': {
			'level': 'DEBUG',
			'class': 'logging.handlers.RotatingFileHandler',
			'filename': '/var/log/duffy/twofishes.log',
			'formatter': 'simple',
			'maxBytes': 1024 * 1024 * 100,  # 100 mb
		}
	},
	'loggers': {
		'django': {
			'handlers':['djangofile', 'djangoerror', 'mail_admins'],
			'propagate': True,
			'level':'DEBUG',
		},
		'photos': {
			'handlers': ['duffyfile', 'mail_admins'],
			'propagate': True,
			'level': 'DEBUG',
		},
		'arbus': {
			'handlers': ['duffyfile'],
			'propagate': True,
			'level': 'DEBUG',
		},
		'strand': {
			'handlers': ['duffyfile', 'mail_admins'],
			'propagate': True,
			'level': 'DEBUG',
		},
		'celery': {
			'handlers': ['celery'],
			'level': 'DEBUG',
		},
		'async.two_fishes': {
			'handlers': ['two_fishes'],
			'level': 'DEBUG',
		},

	}
}

DEFAULT_FROM_EMAIL = 'server-errors@duffytech.co'

EMAIL_HOST = 'email-smtp.us-east-1.amazonaws.com'
EMAIL_PORT = 587
EMAIL_HOST_USER = 'AKIAJHHJPIGXPBWBGSKQ'
EMAIL_HOST_PASSWORD = 'AiAvYbMDxI7DbOlS9wWrsvbyVuykMNwIMnPkefsFH++O'
EMAIL_USE_TLS = True

SERVER_EMAIL = 'prod@duffyapp.com'

ADMINS = (
	('Admins', 'server-errors@duffytech.co'),
)

ALLOWED_HOSTS = ["localhost", "127.0.0.1", "prod.strand.duffyapp.com"]

#S3 Prod server settings
AWS_STORAGE_BUCKET_NAME = 'strand-prod'

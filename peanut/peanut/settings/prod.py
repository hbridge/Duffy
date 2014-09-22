from peanut.settings.base import *

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

DATABASES = {
	'default': {
		'ENGINE': 'django.contrib.gis.db.backends.mysql', 
		'NAME': 'duffy',
		'USER': 'djangouser',
		'PASSWORD': 'djangopass',
		'HOST': 'ec2-54-88-151-106.compute-1.amazonaws.com',   # Or an IP Address that your DB is hosted on
		'PORT': '3306',
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
			'format': '%(levelname)s %(message)s'
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
		}
	},
	'loggers': {
		'django': {
			'handlers':['djangofile', 'djangoerror', 'mail_admins'],
			'propagate': True,
			'level':'DEBUG',
		},
		'photos': {
			'handlers': ['duffyfile'],
			'propagate': True,
			'level': 'DEBUG',
		},
		'arbus': {
			'handlers': ['duffyfile'],
			'propagate': True,
			'level': 'DEBUG',
		},
		'strand': {
			'handlers': ['duffyfile'],
			'propagate': True,
			'level': 'DEBUG',
		},

	}
}

DEFAULT_FROM_EMAIL = 'duffyserver@gmail.com'

EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_HOST_USER = 'duffyserver@gmail.com'
EMAIL_HOST_PASSWORD = 'duffyserver!'
EMAIL_USE_TLS = True

SERVER_EMAIL = 'duffyserver@gmail.com'

ADMINS = (
	('Admins', 'server-errors@duffytech.co'),
)

ALLOWED_HOSTS = ["localhost", "127.0.0.1", "prod.strand.duffyapp.com"]

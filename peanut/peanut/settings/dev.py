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
			'filename': '/home/derek/logs/duffy-all.log',
			'formatter': 'verbose'
		},
		'djangoerror': {
			'level': 'ERROR',
			'class':'logging.handlers.RotatingFileHandler',
			'filename': '/home/derek/logs/duffy-error.log',
			'formatter': 'verbose'
		},
		'duffyfile': {
			'level': 'DEBUG',
			'class':'logging.handlers.RotatingFileHandler',
			'filename': '/home/derek/logs/duffy-photos.log',
			'formatter': 'verbose'
		},
		#'console': {
		#	'level': 'DEBUG',
		#	'class': 'logging.StreamHandler',
		#	'formatter': 'simple'
		#},
	},
	'loggers': {
		'django': {
			'handlers':['djangofile', 'djangoerror'],#, 'console'],
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


STATIC_ROOT = '' # uncomment for static files for dev servers

# Additional locations of static files
STATICFILES_DIRS = (
	# Put strings here, like "/home/html/static" or "C:/www/django/static".
	# Always use forward slashes, even on Windows.
	# Don't forget to use absolute paths, not relative paths.
   '/home/aseem/repos/Duffy/peanut/static',
)
from peanut.settings.base import *

DATABASES = {
	'default': {
		'ENGINE': 'django.contrib.gis.db.backends.mysql', 
		'NAME': 'duffy',
		'USER': 'djangouser',
		'PASSWORD': 'djangopass',
		'HOST': 'localhost',   # Or an IP Address that your DB is hosted on
		'PORT': '3306',
	}
}


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
			'level': 'DEBUG',
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
	},
	'loggers': {
		'django': {
			'handlers':['djangofile', 'djangoerror'],
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
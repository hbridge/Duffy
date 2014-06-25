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

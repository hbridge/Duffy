from peanut.settings.base import *

DATABASES = {
	'default': {
		'ENGINE': 'django.contrib.gis.db.backends.mysql', 
		'NAME': 'duffy',
		'USER': 'duffy',
		'PASSWORD': 'duffy',
		'HOST': 'localhost',   # Or an IP Address that your DB is hosted on
		'PORT': '3306',
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
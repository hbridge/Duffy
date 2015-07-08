from peanut.settings.dev import *

LOCAL = True
DEBUG = True

STATICFILES_DIRS = (
	# Put strings here, like "/home/html/static" or "C:/www/django/static".
	# Always use forward slashes, even on Windows.
	# Don't forget to use absolute paths, not relative paths.
	'/Users/hbridge/Documents/Repos/Duffy/peanut/static',
)

KEEPER_NUMBER = "test"


class CELERY_CONFIG(BASE_CELERY_CONFIG):
	BROKER_URL = "amqp://guest:guest@localhost:5672"

import logging
logging.getLogger('django.db.backends').setLevel(logging.ERROR)

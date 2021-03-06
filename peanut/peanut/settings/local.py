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

# force texts to not send
KEEPER_NUMBER_DICT = {0: KEEPER_NUMBER, 1: KEEPER_NUMBER, 2: KEEPER_NUMBER, 3: KEEPER_NUMBER, 4: KEEPER_NUMBER, 5: "Henry_bot@telegram.me"}
WHATSAPP_SMS_URL = "http://localhost:7500/smskeeper/incoming_sms"
WHATSAPP_CREDENTIALS = ("", "")

if len(sys.argv) > 2:  # If we're running an individual test
	logging.disable(logging.DEBUG)

USE_CACHE = False

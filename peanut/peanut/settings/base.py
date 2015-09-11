"""
Django settings for peanut project.

For more information on this file, see
https://docs.djangoproject.com/en/1.6/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/1.6/ref/settings/
"""

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
import os
import sys
BASE_DIR = os.path.dirname(os.path.dirname(__file__))
from celery.schedules import crontab
import datetime

from kombu import Exchange, Queue

# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/1.6/howto/deployment/checklist/

TEMPLATE_DEBUG = True

ALLOWED_HOSTS = []

# Application definition

INSTALLED_APPS = (
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.gis',
    'arbus',
    'common',
    'strand',
    'memfresh',
    'smskeeper',
    # Added.
    'haystack',
    'rest_framework',
    'ios_notifications',
    'django.contrib.humanize',
    'storages',
    'djcelery',
    'async',
    'django_inbound_email',
    'simple_history'
)

MIDDLEWARE_CLASSES = (
    # Added this to record page load time
    'peanut.middlewares.StatsMiddleware',
    # 'peanut.middlewares.SqlLogMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'simple_history.middleware.HistoryRequestMiddleware',
    # 'snippetscream.ProfileMiddleware', # not compatible with Django 1.7
)

ROOT_URLCONF = 'peanut.urls'

WSGI_APPLICATION = 'peanut.wsgi.application'


# Database
# https://docs.djangoproject.com/en/1.6/ref/settings/#databases

# DATABASES = {
#    'default': {
#        'ENGINE': 'django.db.backends.sqlite3',
#        'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
#    }
# }


HAYSTACK_CONNECTIONS = {
    'default': {
        'ENGINE': 'haystack.backends.solr_backend.SolrEngine',
        'URL': 'http://127.0.0.1:8983/solr'
        # ...or for multicore...
        # 'URL': 'http://127.0.0.1:8983/solr/mysite',
    },
}

# HAYSTACK_SIGNAL_PROCESSOR = 'haystack.signals.RealtimeSignalProcessor'

TEMPLATE_CONTEXT_PROCESSORS = (
    'django.core.context_processors.request',
    "django.contrib.auth.context_processors.auth",
    "django.core.context_processors.debug",
    "django.core.context_processors.i18n",
    "django.core.context_processors.media",
    "django.core.context_processors.static",
    "django.core.context_processors.tz",
    "django.contrib.messages.context_processors.messages",
)

# Internationalization
# https://docs.djangoproject.com/en/1.6/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_L10N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/1.6/howto/static-files/
STATIC_ROOT = os.path.join(BASE_DIR, "static")
STATIC_ROOT = ''  # uncomment for static files for dev servers
STATIC_URL = '/static/'


# Additional locations of static files
STATICFILES_DIRS = (
    # Put strings here, like "/home/html/static" or "C:/www/django/static".
    # Always use forward slashes, even on Windows.
    # Don't forget to use absolute paths, not relative paths.
    # '/home/aseem/repos/Duffy/peanut/static',
)

# List of finder classes that know how to find static files in
# various locations.
STATICFILES_FINDERS = (
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
    # 'django.contrib.staticfiles.finders.DefaultStorageFinder',
)

# Added to suppress timezone warnings
import warnings
warnings.filterwarnings('ignore',
                        r".*received a naive datetime",
                        RuntimeWarning, r'.*')

IOS_NOTIFICATIONS_PERSIST_NOTIFICATIONS = False

# S3 Settings
DEFAULT_FILE_STORAGE = 'storages.backends.s3boto.S3BotoStorage'
AWS_ACCESS_KEY_ID = 'AKIAJBSV42QT6SWHHGBA'
AWS_SECRET_ACCESS_KEY = '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'
AWS_HEADERS = {
    'Content-type': 'image/jpeg'
}
AWS_REGION = "us-east-1"

import djcelery
djcelery.setup_loader()


# settings.py
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': "[%(asctime)s] %(levelname)s [%(name)s:%(lineno)s] %(message)s",
            'datefmt': "%d/%b/%Y %H:%M:%S"
        },
        'simple': {
            'format': '%(asctime)s %(levelname)s %(message)s'
        },
    },
    'filters': {
        'skip_unreadable_posts': {
            '()': 'common.peanut_logging.SkipUnreadablePostError',
        }
    },
    'handlers': {
        'null': {
            'level': 'DEBUG',
            'class': 'logging.NullHandler',
        },
        'mail_admins': {
            'level': 'ERROR',
            'filters': ['skip_unreadable_posts'],
            'class': 'django.utils.log.AdminEmailHandler',
        },
        'slackerror': {
            'level': 'ERROR',
            'class': 'common.slack_logger.SlackLogHandler',
            'stack_trace': True
        },
        'djangofile': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/frontend-all.log',
            'formatter': 'verbose'
        },
        'djangoerror': {
            'level': 'ERROR',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/frontend-error.log',
            'formatter': 'verbose'
        },
        'duffyfile': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/frontend-main.log',
            'formatter': 'verbose'
        },
        'celery': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/celery.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        },
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
            'stream': sys.stdout
        },
    },
    'loggers': {
        # Silence SuspiciousOperation.DisallowedHost exception ('Invalid
        # HTTP_HOST' header messages). Set the handler to 'null' so we don't
        # get those annoying emails.
        'django.security.DisallowedHost': {
            'handlers': ['null'],
            'propagate': False,
        },
        'django': {
            'handlers': ['djangofile', 'djangoerror', 'mail_admins', 'slackerror'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'photos': {
            'handlers': ['duffyfile', 'mail_admins', 'slackerror'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'arbus': {
            'handlers': ['duffyfile', 'mail_admins', 'slackerror'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'strand': {
            'handlers': ['duffyfile', 'mail_admins', 'slackerror'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'celery': {
            'handlers': ['celery', 'duffyfile', 'djangoerror', 'mail_admins', 'slackerror'],
            'level': 'DEBUG',
            'propagate': True,
        },
        'smskeeper': {
            'handlers': ['duffyfile', 'djangoerror', 'mail_admins', 'slackerror', 'console'],
            'level': 'DEBUG',
            'propagate': True,
        },
        'common': {
            'handlers': ['duffyfile', 'djangoerror', 'mail_admins', 'slackerror'],
            'level': 'DEBUG',
            'propagate': True,
        },
        'smskeeper.async': {
            'handlers': ['celery', 'duffyfile', 'djangoerror', 'mail_admins', 'slackerror'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'smskeeper.sms_util': {
            'handlers': ['celery', 'duffyfile', 'djangoerror', 'mail_admins', 'slackerror'],
            'propagate': True,
            'level': 'DEBUG',
        },
    }
}


class BASE_CELERY_CONFIG:
    CELERY_TASK_RESULT_EXPIRES = 3600
    CELERYD_NODES = "keeper"
    CELERY_QUEUES = (
        Queue('default', Exchange('default'), routing_key='default'),
        # 5 threads
        Queue('keeper', Exchange('keeper'), routing_key='keeper'),
    )
    CELERY_ROUTES = {
        'memfresh.async.evalAllUsersForFollowUp': {'queue': 'keeper', 'routing_key': 'keeper'},
        'memfresh.async.evalUserForFollowUp': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.sms_util.asyncSendMsg': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.sms_util.asyncMaybeSendConfusedMsg': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.async.processReminder': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.async.processAllReminders': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.async.sendTips': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.async.testCelery': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.async.processDailyDigest': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.async.sendDigestForUserId': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.async.sendAllRemindersForUserId': {'queue': 'keeper', 'routing_key': 'keeper'},
        'smskeeper.async.suspendInactiveUsers': {'queue': 'keeper', 'routing_key': 'keeper'},
    }

    CELERYBEAT_SCHEDULE = {
        'unactivated-accounts': {
            'task': 'async.notifications.sendUnactivatedAccountFS',
            'schedule': crontab(hour=23, minute=0),
            'args': None,
        },
        'memfresh-followup': {
            'task': 'memfresh.async.evalAllUsersForFollowUp',
            'schedule': crontab(minute=15),
            'args': None,
        },
        'smskeeper-tips': {
            'task': 'smskeeper.async.sendTips',
            'schedule': crontab(minute=5),
            'args': None,
        },
        'smskeeper-reminders': {
            'task': 'smskeeper.async.processAllReminders',
            "schedule": datetime.timedelta(seconds=30),
            'args': None,
        },
        'smskeeper-todo-digest': {
            'task': 'smskeeper.async.processDailyDigest',
            "schedule": crontab(minute='*', hour='*'),
            'args': None,
        }

    }

# the HTTP request parser to use - we set a default as the tests need a valid parser.
INBOUND_EMAIL_PARSER = 'django_inbound_email.backends.mailgun.MailgunRequestParser'

# whether to dump out a log of all incoming email requests
INBOUND_EMAIL_LOG_REQUESTS = True

# the max size (in Bytes) of any attachment to process - defaults to 10MB
INBOUND_EMAIL_ATTACHMENT_SIZE_MAX = 10000000

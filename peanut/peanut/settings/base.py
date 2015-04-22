"""
Django settings for peanut project.

For more information on this file, see
https://docs.djangoproject.com/en/1.6/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/1.6/ref/settings/
"""

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
import os
BASE_DIR = os.path.dirname(os.path.dirname(__file__))
from celery.schedules import crontab

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
    # Added.
    'haystack',
    'rest_framework',
    'ios_notifications',
    'django.contrib.humanize',
    'storages',
    'djcelery',
    'async',
    'django_inbound_email'
)

MIDDLEWARE_CLASSES = (
    # Added this to record page load time
    'peanut.middlewares.StatsMiddleware',
    #'peanut.middlewares.SqlLogMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
#    'snippetscream.ProfileMiddleware', # not compatible with Django 1.7
)

ROOT_URLCONF = 'peanut.urls'

WSGI_APPLICATION = 'peanut.wsgi.application'


# Database
# https://docs.djangoproject.com/en/1.6/ref/settings/#databases

#DATABASES = {
#    'default': {
#        'ENGINE': 'django.db.backends.sqlite3',
#        'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
#    }
#}


HAYSTACK_CONNECTIONS = {
    'default': {
        'ENGINE': 'haystack.backends.solr_backend.SolrEngine',
        'URL': 'http://127.0.0.1:8983/solr'
        # ...or for multicore...
        # 'URL': 'http://127.0.0.1:8983/solr/mysite',
    },
}

#HAYSTACK_SIGNAL_PROCESSOR = 'haystack.signals.RealtimeSignalProcessor'

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
#STATIC_ROOT = '' # uncomment for static files for dev servers
STATIC_URL = '/static/'


# Additional locations of static files
STATICFILES_DIRS = (
    # Put strings here, like "/home/html/static" or "C:/www/django/static".
    # Always use forward slashes, even on Windows.
    # Don't forget to use absolute paths, not relative paths.
#   '/home/aseem/repos/Duffy/peanut/static',
)

# List of finder classes that know how to find static files in
# various locations.
STATICFILES_FINDERS = (
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
#    'django.contrib.staticfiles.finders.DefaultStorageFinder',
)

# Added to suppress timezone warnings
import warnings
warnings.filterwarnings('ignore',
                        r".*received a naive datetime",
                        RuntimeWarning, r'.*')

IOS_NOTIFICATIONS_PERSIST_NOTIFICATIONS = False

#S3 Settings
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
            'format' : "[%(asctime)s] %(levelname)s [%(name)s:%(lineno)s] %(message)s",
            'datefmt' : "%d/%b/%Y %H:%M:%S"
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
        'djangofile': {
            'level': 'INFO',
            'class':'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/frontend-all.log',
            'formatter': 'verbose'
        },
        'djangoerror': {
            'level': 'ERROR',
            'class':'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/frontend-error.log',
            'formatter': 'verbose'
        },
        'duffyfile': {
            'level': 'DEBUG',
            'class':'logging.handlers.RotatingFileHandler',
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
        'two_fishes': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/twofishes.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        },
        'stranding': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/stranding.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        },
        'similarity': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/similarity.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        },
        'popcaches': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/popcaches.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        },
        'neighboring': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/neighboring.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        },
        'friending': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/friending.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        },
        'suggestion-notifications': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/suggestion-notifications.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        },
        'notifications': {
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/mnt/log/notifications.log',
            'formatter': 'simple',
            'maxBytes': 1024 * 1024 * 100,  # 100 mb
        }
        #'console': {
        #   'level': 'DEBUG',
        #   'class': 'logging.StreamHandler',
        #   'formatter': 'simple'
        #},
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
            'handlers':['djangofile', 'djangoerror', 'mail_admins'],#, 'console'],
            'propagate': True,
            'level':'DEBUG',
        },
        'photos': {
            'handlers': ['duffyfile', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'arbus': {
            'handlers': ['duffyfile', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'strand': {
            'handlers': ['duffyfile', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'celery': {
            'handlers': ['celery', 'mail_admins'],
            'level': 'DEBUG',
            'propagate': True,
        },
        'async.two_fishes': {
            'handlers': ['two_fishes', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.stranding': {
            'handlers': ['stranding', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.similarity': {
            'handlers': ['similarity', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.popcaches': {
            'handlers': ['popcaches', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.neighboring': {
            'handlers': ['neighboring', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.friending': {
            'handlers': ['friending', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.suggestion_notifications': {
            'handlers': ['suggestion-notifications', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.notifications': {
            'handlers': ['notifications', 'mail_admins'],
            'propagate': True,
            'level': 'DEBUG',
        },
    }
}
class BASE_CELERY_CONFIG:
    CELERY_TASK_RESULT_EXPIRES=3600
    CELERYD_NODES="independent stranding popcaches ordered_low"
    CELERY_QUEUES = (
        Queue('default', Exchange('default'), routing_key='default'),
        # 10 threads
        Queue('independent', Exchange('independent'), routing_key='independent'),
        # 1 thread
        Queue('stranding', Exchange('stranding'), routing_key='stranding'),
        Queue('popcaches', Exchange('popcaches'), routing_key='popcaches'),
        Queue('ordered_low', Exchange('ordered_low'), routing_key='ordered_low'),
    )
    CELERY_ROUTES = {
        'async.two_fishes.processAll': {'queue': 'independent', 'routing_key': 'independent'},
        'async.two_fishes.processIds': {'queue': 'independent', 'routing_key': 'independent'},
        'async.stranding.processAll': {'queue': 'stranding', 'routing_key': 'stranding'},
        'async.stranding.processIds': {'queue': 'stranding', 'routing_key': 'stranding'},
        'async.stranding.processUserIdsForFriendGPSInfoAppTask': {'queue': 'ordered_low', 'routing_key': 'ordered_low'},   
        'async.popcaches.processPrivateStrandsAll': {'queue': 'popcaches', 'routing_key': 'popcaches'},
        'async.popcaches.processPrivateStrandIds': {'queue': 'popcaches', 'routing_key': 'popcaches'},
        'async.popcaches.processPrivateStrandFull': {'queue': 'ordered_low', 'routing_key': 'ordered_low'},
        'async.popcaches.processInboxAll': {'queue': 'popcaches', 'routing_key': 'popcaches'},
        'async.popcaches.processInboxIds': {'queue': 'popcaches', 'routing_key': 'popcaches'},
        'async.popcaches.processInboxFull': {'queue': 'ordered_low', 'routing_key': 'ordered_low'},
        'async.similarity.processAll': {'queue': 'independent', 'routing_key': 'independent'},
        'async.similarity.processIds': {'queue': 'independent', 'routing_key': 'independent'},
        'async.neighboring.processAllStrands': {'queue': 'independent', 'routing_key': 'independent'},
        'async.neighboring.processStrandIds': {'queue': 'independent', 'routing_key': 'independent'},
        'async.neighboring.processAllLocationRecords': {'queue': 'independent', 'routing_key': 'independent'},
        'async.neighboring.processLocationRecordIds': {'queue': 'independent', 'routing_key': 'independent'},
        'async.friending.processIds': {'queue': 'independent', 'routing_key': 'independent'},
        'async.friending.processAll': {'queue': 'independent', 'routing_key': 'independent'},
        'async.suggestion_notifications.processIds': {'queue': 'ordered_low', 'routing_key': 'ordered_low'},
        'async.suggestion_notifications.processUserId': {'queue': 'ordered_low', 'routing_key': 'ordered_low'},
        'async.notifications.sendRefreshFeedToUserIds': {'queue': 'independent', 'routing_key': 'independent'},
        'async.notifications.sendNewPhotoNotificationBatch': {'queue': 'independent', 'routing_key': 'independent'},
        'async.notifications.sendAddFriendNotificationFromActions': {'queue': 'independent', 'routing_key': 'independent'},
        'async.notifications.sendUnactivatedAccountFS': {'queue': 'independent', 'routing_key': 'independent'},
        'async.notifications.sendRequestPhotosNotification': {'queue': 'independent', 'routing_key': 'independent'},
        'async.internal.sendEmailForIncomingSMS': {'queue': 'ordered_low', 'routing_key': 'ordered_low'},
        'memfresh.async.evalAllUsersForFollowUp': {'queue': 'ordered_low', 'routing_key': 'ordered_low'},
        'memfresh.async.evalUserForFollowUp': {'queue': 'ordered_low', 'routing_key': 'ordered_low'},

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
        }
}

# the HTTP request parser to use - we set a default as the tests need a valid parser.
INBOUND_EMAIL_PARSER = 'django_inbound_email.backends.mailgun.MailgunRequestParser'

# whether to dump out a log of all incoming email requests
INBOUND_EMAIL_LOG_REQUESTS = True

# the max size (in Bytes) of any attachment to process - defaults to 10MB
INBOUND_EMAIL_ATTACHMENT_SIZE_MAX = 10000000


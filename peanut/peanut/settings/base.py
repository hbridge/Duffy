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
    # Added.
    'haystack',
    'rest_framework',
    'ios_notifications',
    'django.contrib.humanize',
    'storages',
    'djcelery',
    'async'
)

MIDDLEWARE_CLASSES = (
    # Added this to record page load time
    'peanut.middlewares.StatsMiddleware',
    'peanut.middlewares.SqlLogMiddleware',
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
    'handlers': {
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
        }
        #'console': {
        #   'level': 'DEBUG',
        #   'class': 'logging.StreamHandler',
        #   'formatter': 'simple'
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
        'celery': {
            'handlers': ['celery'],
            'level': 'DEBUG',
            'propagate': True,
        },
        'async.two_fishes': {
            'handlers': ['two_fishes'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.stranding': {
            'handlers': ['stranding'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.similarity': {
            'handlers': ['similarity'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.popcaches': {
            'handlers': ['popcaches'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.neighboring': {
            'handlers': ['neighboring'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.friending': {
            'handlers': ['friending'],
            'propagate': True,
            'level': 'DEBUG',
        },
        'async.suggestion_notifications': {
            'handlers': ['suggestion-notifications'],
            'propagate': True,
            'level': 'DEBUG',
        },
    }
}

class BASE_CELERY_CONFIG:
    CELERY_TASK_RESULT_EXPIRES=3600
    CELERYD_CONCURRENCY=4
    CELERY_QUEUES = (
        Queue('default', Exchange('default'), routing_key='default'),
        Queue('for_two_fishes', Exchange('for_two_fishes'), routing_key='for_two_fishes'),
        Queue('for_stranding', Exchange('for_stranding'), routing_key='for_stranding'),
        Queue('for_popcaches', Exchange('for_popcaches'), routing_key='for_popcaches'),
        Queue('for_popcaches_full', Exchange('for_popcaches_full'), routing_key='for_popcaches_full'),
        Queue('for_similarity', Exchange('for_similarity'), routing_key='for_similarity'),
        Queue('for_neighboring', Exchange('for_neighboring'), routing_key='for_neighboring'),
        Queue('for_friending', Exchange('for_friending'), routing_key='for_friending'),
        Queue('for_suggestion_notifications', Exchange('for_suggestion_notifications'), routing_key='for_suggestion_notifications'),
    )
    CELERY_ROUTES = {
        'async.two_fishes.processAll': {'queue': 'for_two_fishes', 'routing_key': 'for_two_fishes'},
        'async.two_fishes.processIds': {'queue': 'for_two_fishes', 'routing_key': 'for_two_fishes'},
        'async.stranding.processAll': {'queue': 'for_stranding', 'routing_key': 'for_stranding'},
        'async.stranding.processIds': {'queue': 'for_stranding', 'routing_key': 'for_stranding'},
        'async.popcaches.processAll': {'queue': 'for_popcaches', 'routing_key': 'for_popcaches'},
        'async.popcaches.processIds': {'queue': 'for_popcaches', 'routing_key': 'for_popcaches'},
        'async.popcaches.processFull': {'queue': 'for_popcaches_full', 'routing_key': 'for_popcaches_full'},
        'async.similarity.processAll': {'queue': 'for_similarity', 'routing_key': 'for_similarity'},
        'async.similarity.processIds': {'queue': 'for_similarity', 'routing_key': 'for_similarity'},
        'async.neighboring.processAllStrands': {'queue': 'for_neighboring', 'routing_key': 'for_neighboring'},
        'async.neighboring.processStrandIds': {'queue': 'for_neighboring', 'routing_key': 'for_neighboring'},
        'async.neighboring.processAllLocationRecords': {'queue': 'for_neighboring', 'routing_key': 'for_neighboring'},
        'async.neighboring.processLocationRecordIds': {'queue': 'for_neighboring', 'routing_key': 'for_neighboring'},
        'async.friending.processIds': {'queue': 'for_friending', 'routing_key': 'for_friending'},
        'async.friending.processAll': {'queue': 'for_friending', 'routing_key': 'for_friending'},
        'async.suggestion_notifications.processIds': {'queue': 'for_suggestion_notifications', 'routing_key': 'for_suggestion_notifications'},
        'async.suggestion_notifications.processUserId': {'queue': 'for_suggestion_notifications', 'routing_key': 'for_suggestion_notifications'},

    }

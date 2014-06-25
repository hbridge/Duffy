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


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/1.6/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'f(*vzc)x9!1-5nis+uinolh=$*&#z@&2n!7)x9#x@&n2s=-)vb'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

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
    'ios_notifications'
)

MIDDLEWARE_CLASSES = (
    # Added this to record page load time
    'peanut.middlewares.StatsMiddleware',

    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'snippetscream.ProfileMiddleware',
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

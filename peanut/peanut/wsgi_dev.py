"""
WSGI config for peanut project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/1.6/howto/deployment/wsgi/
"""

import os, sys, site

site.addsitedir('/home/ubuntu/env/local/lib/python2.7/site-packages')

sys.path.append('/home/ubuntu/dev/Duffy/peanut')

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings.dev")

# Activate your virtual env
activate_env=os.path.expanduser("/home/ubuntu/env/bin/activate_this.py")
execfile(activate_env, dict(__file__=activate_env))

from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()

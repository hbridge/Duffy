from peanut.settings.dev import *

LOCAL = False

STATICFILES_DIRS = (
	# Put strings here, like "/home/html/static" or "C:/www/django/static".
	# Always use forward slashes, even on Windows.
	# Don't forget to use absolute paths, not relative paths.
	'/home/derek/Duffy/peanut/static',
)

KEEPER_NUMBER_DICT = {0: "+12488178301", 1: "+12488178301", 2: "+12488178301", 3: "+12488178301"}

if len(sys.argv) > 2 and 'simulate' not in sys.argv[2]:  # If we're running an individual test
	logging.disable(None)

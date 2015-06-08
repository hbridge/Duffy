from mixpanel import Mixpanel
from django.conf import settings


mp = Mixpanel(settings.MIXPANEL_TOKEN)


def logUserEvent(user, eventName, parametersDict=None):
	# don't send for tests or for founders (id <= 3)
	if settings.MIXPANEL_TOKEN is not None and user.id > 3:
		mp.track(user.id, eventName, parametersDict)

	else:
		print "%s: %s" % (eventName, parametersDict)

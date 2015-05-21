from mixpanel import Mixpanel
from django.conf import settings


mp = Mixpanel(settings.MIXPANEL_TOKEN)


def logUserEvent(user, eventName, parametersDict=None):
	mp.track(user.id, eventName, parametersDict)

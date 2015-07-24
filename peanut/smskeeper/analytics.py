from mixpanel import Mixpanel
from django.conf import settings
from smskeeper import time_utils

mp = Mixpanel(settings.MIXPANEL_TOKEN)


def logUserEvent(user, eventName, parametersDict=None):
	# don't send for tests or for founders (id <= 3)
	if settings.MIXPANEL_TOKEN is not None and user.id > 3:
		if not parametersDict:
			parametersDict = {}
		parametersDict['User Product ID'] = user.product_id
		parametersDict['User Source'] = user.getSignupData('source'),
		parametersDict['User Experiment'] = user.getSignupData('exp'),
		parametersDict['User Paid'] = user.getSignupData('paid')
		parametersDict["In tutorial"] = not user.isTutorialComplete()

		if user.activated:
			accountActivatedDays, hours = time_utils.daysAndHoursAgo(user.activated)
			parametersDict['User Activated Days'] = accountActivatedDays

		mp.track(user.id, eventName, parametersDict)


def setUserInfo(user):
	mp.people_set(user.id, {
		'$first_name': user.name,
		'$phone': user.phone_number,
		'product_id': user.product_id,
		'source': user.getSignupData('source'),
		'exp': user.getSignupData('exp'),
		'paid': user.getSignupData('paid')
	})

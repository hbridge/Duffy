import datetime
import pytz

from django.test import TestCase
from django.conf import settings

from smskeeper.models import User, ZipData
from smskeeper import keeper_constants
from common import natty_util

# turn off mixpanel for tests
settings.MIXPANEL_TOKEN = None


class SMSKeeperBaseCase(TestCase):
	testPhoneNumber = "+16505555550"
	user = None

	def setUp(self):
		try:
			user = User.objects.get(phone_number=self.testPhoneNumber)
			user.delete()
		except User.DoesNotExist:
			pass

		# Need to do this everytime otherwise if we're doing things in timezones in the code
		# then the database will be empty and default to Eastern
		self.setupZipCodeData()

	def setupZipCodeData(self):
		ZipData.objects.create(city="San Francisco", state="CA", zip_code="94117", timezone="PST", area_code="415")
		ZipData.objects.create(city="Manhattan", state="NY", zip_code="10012", timezone="EST", area_code="212")
		ZipData.objects.create(city="New York", state="NY", zip_code="10012", timezone="EST", area_code="212")

	# TODO(Derek): Eventually activated and tutorialComplete should go away
	def setupUser(self, activated, tutorialComplete, state=keeper_constants.STATE_NORMAL, productId=None):
		self.user, created = User.objects.get_or_create(phone_number=self.testPhoneNumber)
		self.user.completed_tutorial = tutorialComplete
		if activated:
			self.user.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		if productId:
			self.user.product_id = productId
		self.user.state = state
		self.user.save()
		return self.user

	def getTestUser(self):
		return User.objects.get(id=self.user.id)

	def getUserNow(self):
		now = datetime.datetime.now(pytz.utc)
		# This could be sped up with caching
		return now.astimezone(self.getTestUser().getTimezone())

	def getOutput(self, mock):
		output = u""
		for call in mock.call_args_list:
			arg, kargs = call
			output += unicode(arg[0].decode('utf-8'))

		return output

	# intended to be used with a mock of smskeeper.analytics.logUserEvent
	def getAnalyticsEvents(self, mock):
		events = []
		for call in mock.call_args_list:
			arg, kargs = call
			events.append({
				"user": arg[0],
				"event": arg[1],
				"params": arg[2]
			})

		return events

	# Day, hasDate, hasTime
	# These should all in UTC
	MON_8AM = ([2015, 6, 1, 12, 0, 0], True, True)
	MON_9AM = ([2015, 6, 1, 13, 0, 0], True, True)
	TUE_8AM = ([2015, 6, 2, 12, 0, 0], True, True)
	TUE_9AM = ([2015, 6, 2, 13, 0, 0], True, True)
	TUE_850AM = ([2015, 6, 2, 12, 50, 0], True, True)
	TUE = ([2015, 6, 2, 12, 0, 0], True, False)
	WEEKEND = ([2015, 6, 6, 12, 0, 0], True, False)
	ONLY_4PM = ([2015, 6, 1, 20, 0, 0], False, True)
	NEXT_WEEK = ([2015, 6, 8, 12, 0, 0], True, False)
	SUNDAY_7PM = ([2015, 6, 7, 23, 0, 0], True, True)

	NO_TIME = ([2010, 6, 1, 8, 0, 0], False, False)

	def setNow(self, dateMock, date):
		d, hasDate, hasTime = date
		dateMock.return_value = datetime.datetime(d[0], d[1], d[2], d[3], d[4], d[5], tzinfo=pytz.utc)

	def setupNatty(self, nattyMock, date, queryWithoutTiming, usedText):
		d, hasDate, hasTime = date
		dt = datetime.datetime(d[0], d[1], d[2], d[3], d[4], d[5], tzinfo=pytz.utc)
		nattyMock.return_value = [natty_util.NattyResult(dt, queryWithoutTiming, usedText, hasDate, hasTime)]

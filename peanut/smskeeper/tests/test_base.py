import datetime
import pytz

from django.test import TestCase
from django.conf import settings

from smskeeper.models import User, ZipData
from smskeeper import keeper_constants

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
	def setupUser(self, activated, tutorialComplete, state=keeper_constants.STATE_NORMAL):
		self.user, created = User.objects.get_or_create(phone_number=self.testPhoneNumber)
		self.user.completed_tutorial = tutorialComplete
		if (activated):
			self.user.activated = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
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
import datetime
import pytz

from django.test import TestCase
from django.conf import settings

from smskeeper.models import User, ZipData, VerbData
from smskeeper import keeper_constants
import emoji

from common import date_util

# turn off mixpanel for tests
settings.MIXPANEL_TOKEN = None


class SMSKeeperBaseCase(TestCase):
	testPhoneNumber = "+16505555550"
	user = None
	mockedDate = None

	def setUp(self):
		try:
			user = User.objects.get(phone_number=self.testPhoneNumber)
			user.delete()
		except User.DoesNotExist:
			pass

		# Need to do this everytime otherwise if we're doing things in timezones in the code
		# then the database will be empty and default to Eastern
		self.setupZipCodeData()

		self.setupVerbData()

		settings.KEEPER_NUMBER_DICT = {0: "test0", 1: "test1", 2: "test@s.whatsapp.net", 3: "test2"}

	def setupZipCodeData(self):
		ZipData.objects.create(city="San Francisco", state="CA", country_code="US", wxcode="94117", postal_code="94117", timezone="PST", area_code="415")
		ZipData.objects.create(city="Manhattan", state="NY", country_code="US", wxcode="10012", postal_code="10012", timezone="EST", area_code="212")
		ZipData.objects.create(city="New York", state="NY", country_code="US", wxcode="10012", postal_code="10012", timezone="EST", area_code="212")
		ZipData.objects.create(city="Milltimber", state="Aberdeenshire", country_code="UK", wxcode="UKXX0333", postal_code="AB13", timezone="Europe/London")
		ZipData.objects.create(city="Milltimber", state="Aberdeenshire", country_code="UK", wxcode="UKXX0333", postal_code="N2H", timezone="Europe/London")
		ZipData.objects.create(city="Gurgaon", state="HR", country_code="IN", wxcode="INXX0342", postal_code="55555", timezone="Asia/Kolkata")

	def setupVerbData(self):
		VerbData.objects.create(past="done")
		VerbData.objects.create(past="got")

	# TODO(Derek): Eventually activated and tutorialComplete should go away
	def setupUser(self, activated, tutorialComplete, state=keeper_constants.STATE_NORMAL, productId=None, dateMock=None):
		self.user = self.setupAnotherUser(self.testPhoneNumber, activated, tutorialComplete, state, productId, dateMock)

		return self.user

	def setupAnotherUser(self, phoneNumber, activated, tutorialComplete, state=keeper_constants.STATE_NORMAL, productId=None, dateMock=None):
		if dateMock:
			self.setNow(dateMock, self.TUE_8AM)

		user, created = User.objects.get_or_create(phone_number=phoneNumber)
		user.completed_tutorial = tutorialComplete
		if activated:
			dt = date_util.now(pytz.utc)
			user.activated = datetime.datetime(day=dt.day, year=dt.year, month=dt.month, hour=dt.hour, minute=dt.minute, second=dt.second).replace(tzinfo=pytz.utc)
			user.name = "Test User%s" % phoneNumber[7:]
		if productId:
			user.product_id = productId
		user.state = state
		user.signature_num_lines = 0
		user.save()

		return user

	def getTestUser(self):
		return User.objects.get(id=self.user.id)

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

	def containsOneOf(self, output, stringList, substitute=None):
		for s in stringList:
			if substitute:
				if emoji.emojize(s % substitute, use_aliases=True) in output:
					return True
			else:
				if emoji.emojize(s, use_aliases=True) in output:
					return True
		return False

	def assertContainsOneOf(self, output, stringList, substitute=None):
		self.assertTrue(self.containsOneOf(output, stringList, substitute), "String wasn't found in '%s'" % output)

	def assertNotContainsOneOf(self, output, stringList):
		self.assertFalse(self.containsOneOf(output, stringList), "String did match: %s" % output)

	def renderTextConstant(self, constant):
		if isinstance(constant, list):
			return map(lambda txt: self.renderTextConstant(txt), constant)
		return emoji.emojize(constant, True)

	# Day, hasDate, hasTime
	# These should all in UTC
	MON_2AM = datetime.datetime(2015, 6, 1, 6, 0, 0, tzinfo=pytz.utc)
	MON_6AM = datetime.datetime(2015, 6, 1, 10, 0, 0, tzinfo=pytz.utc)
	MON_8AM = datetime.datetime(2015, 6, 1, 12, 0, 0, tzinfo=pytz.utc)
	MON_9AM = datetime.datetime(2015, 6, 1, 13, 0, 0, tzinfo=pytz.utc)
	MON_10AM = datetime.datetime(2015, 6, 1, 14, 0, 0, tzinfo=pytz.utc)
	MON_11AM = datetime.datetime(2015, 6, 1, 15, 0, 0, tzinfo=pytz.utc)
	MON_1PM = datetime.datetime(2015, 6, 1, 17, 0, 0, tzinfo=pytz.utc)
	MON_2PM = datetime.datetime(2015, 6, 1, 18, 0, 0, tzinfo=pytz.utc)
	MON_3PM = datetime.datetime(2015, 6, 1, 19, 0, 0, tzinfo=pytz.utc)
	MON_4PM = datetime.datetime(2015, 6, 1, 20, 0, 0, tzinfo=pytz.utc)
	MON_5PM = datetime.datetime(2015, 6, 1, 21, 0, 0, tzinfo=pytz.utc)
	MON_6PM = datetime.datetime(2015, 6, 1, 22, 0, 0, tzinfo=pytz.utc)
	MON_8PM = datetime.datetime(2015, 6, 2, 0, 0, 0, tzinfo=pytz.utc)
	MON_10PM = datetime.datetime(2015, 6, 2, 2, 0, 0, tzinfo=pytz.utc)
	TUE_1AM = datetime.datetime(2015, 6, 2, 5, 0, 0, tzinfo=pytz.utc)
	TUE_5AM = datetime.datetime(2015, 6, 2, 9, 0, 0, tzinfo=pytz.utc)
	TUE_8AM = datetime.datetime(2015, 6, 2, 12, 0, 0, tzinfo=pytz.utc)
	TUE_9AM = datetime.datetime(2015, 6, 2, 13, 0, 0, tzinfo=pytz.utc)
	TUE_10AM = datetime.datetime(2015, 6, 2, 14, 0, 0, tzinfo=pytz.utc)
	TUE_1AM = datetime.datetime(2015, 6, 2, 5, 0, 0, tzinfo=pytz.utc)
	TUE_2PM = datetime.datetime(2015, 6, 2, 18, 0, 0, tzinfo=pytz.utc)
	TUE_3PM = datetime.datetime(2015, 6, 2, 19, 0, 0, tzinfo=pytz.utc)
	TUE_6PM = datetime.datetime(2015, 6, 2, 22, 0, 0, tzinfo=pytz.utc)
	TUE_10PM = datetime.datetime(2015, 6, 3, 2, 0, 0, tzinfo=pytz.utc)
	TUE_850AM = datetime.datetime(2015, 6, 2, 12, 50, 0, tzinfo=pytz.utc)
	TUE_858AM = datetime.datetime(2015, 6, 2, 12, 58, 0, tzinfo=pytz.utc)
	WED_9AM = datetime.datetime(2015, 6, 3, 13, 0, 0, tzinfo=pytz.utc)
	THU_9AM = datetime.datetime(2015, 6, 4, 13, 0, 0, tzinfo=pytz.utc)
	THU_10AM = datetime.datetime(2015, 6, 4, 14, 0, 0, tzinfo=pytz.utc)
	THU_6PM = datetime.datetime(2015, 6, 4, 22, 0, 0, tzinfo=pytz.utc)
	FRI_9AM = datetime.datetime(2015, 6, 5, 13, 0, 0, tzinfo=pytz.utc)
	SAT_9AM = datetime.datetime(2015, 6, 6, 13, 0, 0, tzinfo=pytz.utc)
	SUNDAY_7PM = datetime.datetime(2015, 6, 7, 23, 0, 0, tzinfo=pytz.utc)

	def setNow(self, dateMock, date):
		dateMock.return_value = date
		self.mockedDate = date

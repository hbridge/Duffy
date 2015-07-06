# to run use ./manage.py test smskeeper.scripts.test_parsing

import urllib2
from urllib2 import URLError
from mock import patch

from smskeeper.tests import test_base
import json

from smskeeper import cliMsg
from smskeeper import keeper_constants
from smskeeper.models import User
import mechanize


class SMSKeeperParsingCase(test_base.SMSKeeperBaseCase):

	def test_parse_accuracy(self):
		self.setupAuthenticatedBrowser()

		print "Getting list of classified users..."
		try:
			response = urllib2.urlopen("http://prod.strand.duffyapp.com/smskeeper/classified_users").read()
		except URLError as e:
			print "Could not connect to prod server: %@" % (e)
			response = {"users": []}

		classified_users = json.loads(response)["users"]
		print "Replaying messages for %d users..." % len(classified_users)

		message_count = 0
		unknown_count = 0

		testPhoneNumInt = 16505550000
		for user_id in classified_users:
			print "Replaying user %d with testPhoneNumInt: %d" % (user_id, testPhoneNumInt)
			# setup the user
			if testPhoneNumInt >= 16505560000:
				raise NameError('too many test users')
			self.testPhoneNumber = "+%d" % testPhoneNumInt
			testPhoneNumInt += 1
			self.setupUser(activated=True, tutorialComplete=False, productId=1, state=keeper_constants.STATE_TUTORIAL_TODO)

			# get the messages for that user
			try:
				self.browser.open("http://prod.strand.duffyapp.com/smskeeper/message_feed?user_id=%d" % user_id)
				messages_response = self.browser.response().read()
			except URLError as e:
				print "Could not connect to prod server for messages: %@" % (e)
				messages_response = {"messages": []}

			# replay them one by one, checking for unknown in each pass
			for message in json.loads(messages_response)["messages"]:
				if not message.get("incoming", False):
					continue

				with patch('smskeeper.msg_util.timezoneForZipcode') as mock_tz:
					mock_tz.return_value = "PST"
					with patch('smskeeper.sms_util.recordOutput') as mock:
						cliMsg.msg(self.testPhoneNumber, message["Body"])
						print "%s: %s" % (self.testPhoneNumber, message["Body"])
						print "Keeper: %s" % (self.getOutput(mock))

				message_count += 1
				self.user = User.objects.get(id=self.user.id)
				if self.user.paused:
					unknown_count += 1
					self.user.paused = False
					self.user.save()

		print (
			"----------\n"
			+ "%d messages" % message_count
			+ "\n%d unknown" % unknown_count
			+ "\n%.02f unknown rate" % (float(unknown_count) / float(message_count))
			+ "\n\n"
		)

	def setupAuthenticatedBrowser(self):
		print "Logging in to prod..."
		self.browser = mechanize.Browser()
		self.browser.open('http://prod.strand.duffyapp.com/admin/login/')
		self.browser.form = self.browser.forms().next()
		self.browser['username'] = 'henry'
		self.browser['password'] = 'duffy'
		self.browser.submit()

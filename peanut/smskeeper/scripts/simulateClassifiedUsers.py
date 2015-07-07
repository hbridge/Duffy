# to run use ./manage.py test smskeeper.scripts.simulateClassifiedUsers

import urllib2
from urllib2 import URLError
from mock import patch

from smskeeper.tests import test_base
import json

from smskeeper import cliMsg
from smskeeper import keeper_constants
from smskeeper.models import User
import mechanize

from datetime import timedelta
from smskeeper import async
from dateutil import parser


@patch('common.date_util.utcnow')
class SMSKeeperParsingCase(test_base.SMSKeeperBaseCase):

	def test_parse_accuracy(self, dateMock):
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
			print "\nReplaying user %d with testPhoneNumInt: %d" % (user_id, testPhoneNumInt)
			# setup the user
			#if testPhoneNumInt >= 16505550002:
			# TODO temporary for testing
			#break

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

			messages = json.loads(messages_response)["messages"]
			self.setNow(dateMock, parser.parse(messages[0]["added"]))

			# replay them one by one, checking for unknown in each pass
			for message in messages:
				# set the time/state correctly for the message
				message_date = parser.parse(message["added"])
				if self.mockedDate > message_date:
					self.setNow(dateMock, message_date)
				elif self.mockedDate < message_date:
					lastState = self.user.state
					while self.mockedDate < message_date - timedelta(minutes=2):
						newTime = self.mockedDate + timedelta(minutes=2)
						# print "dateMock %s message_date %s newTime %s" % (self.mockedDate, message_date, newTime)
						self.setNow(dateMock, newTime)
						with patch('smskeeper.sms_util.recordOutput') as mock:
							async.processDailyDigest()
							async.sendTips()
							async.processAllReminders()
							output = self.getOutput(mock)
							if output != "":
								print "Keeper (%s): %s" % (self.mockedDate.strftime("%m/%d %H:%M"), self.getOutput(mock))
						if self.user.state != lastState:
							print "state changed to: %s" % self.user.state
							lastState = self.user.state

				if not message.get("incoming", False):
					continue

				with patch('smskeeper.msg_util.timezoneForZipcode') as mock_tz:
					mock_tz.return_value = "PST"
					with patch('smskeeper.sms_util.recordOutput') as mock:
						cliMsg.msg(self.testPhoneNumber, message["Body"])
						print "%s (%s, %s): %s" % (
							self.testPhoneNumber,
							self.mockedDate.strftime("%m/%d %H:%M"),
							self.user.state, message["Body"]
						)
						output = self.getOutput(mock)
						if output != "":
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

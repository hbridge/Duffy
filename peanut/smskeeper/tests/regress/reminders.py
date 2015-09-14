# to run use ./manage.py test smskeeper.tests.regress.reminders
import datetime
import pytz

from urllib2 import URLError
from mock import patch

from smskeeper import cliMsg
from smskeeper.tests import test_base
from smskeeper.models import Entry, User

import json
import logging
import mechanize


class MyLogger:
	filePath = None
	fileHandle = None

	def __init__(self, filePath):
		self.filePath = filePath
		self.fileHandle = open(filePath, 'w')

	def info(self, formatStr, *args):
		formatted = formatStr % args
		if type(formatted) == unicode:
			formatted = formatted.encode('utf-8')
		self.fileHandle.write("%s\n" % formatted)

	def finalize(self):
		self.fileHandle.close()

logger = MyLogger("/mnt/log/regression-reminders.log")

MAX_USERS_TO_SIMULATE = 10000


# Start of reminders regression tests
# Skips entries that have non-simple orig_text
# Could be improved by making sure followups work
@patch('common.date_util.utcnow')
class SMSRemindersRegressionCase(test_base.SMSKeeperBaseCase):

	def setupUser(self, dateMock):
		# All tests start at Tuesday 8am
		self.setNow(dateMock, self.TUE_8AM)
		super(SMSRemindersRegressionCase, self).setupUser(True, True, productId=1)

	def clearData(self):
		try:
			user = User.objects.get(phone_number=self.testPhoneNumber)
			user.delete()
		except User.DoesNotExist:
			pass

		for entry in Entry.objects.filter(label="#reminders"):
			entry.delete()

	def test_reminder_regressions(self, dateMock):
		print "Running Regression tests..."
		logging.disable(logging.CRITICAL)
		#  credentials = {'host': 'localhost:8000', 'username': 'tests', 'password': 'tests'}
		credentials = {'host': 'prod.strand.duffyapp.com', 'username': 'tests', 'password': 'RegressionTestsAreSoCool'}
		self.setupAuthenticatedBrowser(credentials)

		logger.info("Getting list of classified users...")
		try:
			response = self.browser.open("http://%s/smskeeper/approved_todos" % credentials["host"]).read()
		except URLError as e:
			logger.info("Could not connect to server: %s" % (e))
			response = {"users": []}

		entriesData = json.loads(response)["entries"]

		newFailures = list()
		stillFailures = list()
		correct = list()
		newCorrect = list()

		for entryData in entriesData[:1000]:
			if not entryData['orig_text']:
				#  print "Skipped entry with no orig_text"
				continue

			# This really should be done on the sending server
			entryData['orig_text'] = entryData['orig_text'].replace('\r', '\\r')
			entryData['orig_text'] = entryData['orig_text'].replace('\n', '\\n')
			origTexts = json.loads(entryData['orig_text'])

			if len(origTexts) == 1:
				self.clearData()
				self.setupUser(dateMock)
				user = self.getTestUser()
				user.timezone = entryData["creator_timezone"]
				user.save()

				added = datetime.datetime.strptime(entryData['added'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=pytz.utc)
				correctRemindTime = datetime.datetime.strptime(entryData['remind_timestamp'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=pytz.utc)

				self.setNow(dateMock, added)

				origText = origTexts[0]

				cliMsg.msg(self.testPhoneNumber, origText)
				entries = Entry.objects.filter(label="#reminders")

				if len(entries) == 0:
					#  print "FAILED Entry not created for '%s'" % origText
					pass
				elif len(entries) > 1:
					#  print "FAILED Too many entries created for '%s'" % origText
					pass
				elif len(entries) == 1:
					entry = entries[0]

					diff = entry.remind_timestamp - correctRemindTime
					output = "%s '%s': Wrong: %s  Correct: %s   %s" % (entryData['id'], origText, entry.remind_timestamp, correctRemindTime, entryData["manually_updated"])

					if abs(diff.total_seconds()) > 60:
						# Failed, but lets see if we already did or not
						if entryData["manually_updated"]:
							stillFailures.append(output)
						else:
							newFailures.append(output)
					else:
						# Failed, but lets see if we already did or not
						if entryData["manually_updated"]:
							newCorrect.append(output)
						else:
							correct.append(output)

			elif len(origTexts) == 0:
				#  print "Skipped entry with no orig_text"
				pass
			else:
				#  print "Skipped entry with too many orig_text"
				pass

		print "Correct: (%s)" % len(correct)
		print "New correct: (%s)" % len(newCorrect)

		print "Still Failures: (%s)" % len(stillFailures)
		for msg in stillFailures:
			print msg

		print "New Failures: (%s)" % len(newFailures)
		for msg in newFailures:
			print msg

		self.assertEqual(0, len(newFailures))

		logger.finalize()

	def setupAuthenticatedBrowser(self, credentials):
		logger.info("Logging in to prod...")
		self.browser = mechanize.Browser()
		self.browser.open('http://%s/admin/login/' % credentials['host'])
		self.browser.form = self.browser.forms().next()
		self.browser['username'] = credentials['username']
		self.browser['password'] = credentials['password']
		self.browser.submit()

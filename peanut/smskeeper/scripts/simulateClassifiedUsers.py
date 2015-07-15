# to run use ./manage.py test smskeeper.scripts.simulateClassifiedUsers

import urllib2
from urllib2 import URLError
from mock import patch

from smskeeper.tests import test_base
import json

from smskeeper import cliMsg
from smskeeper import keeper_constants
from smskeeper.models import User
from smskeeper.models import Message
import mechanize

from datetime import timedelta
from smskeeper import async
from dateutil import parser
import copy

from smskeeper import user_util
from smskeeper.scripts import importZipdata

from datetime import datetime


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

logger = MyLogger("/mnt/log/keeperSimulation.log")

MAX_USERS_TO_SIMULATE = 10000


@patch('common.date_util.utcnow')
class SMSKeeperParsingCase(test_base.SMSKeeperBaseCase):

	def test_parse_accuracy(self, dateMock):
		logger.info("Starting simulation on %s", datetime.now())
		self.setupAuthenticatedBrowser()

		logger.info("Importing zip data...")
		importZipdata.loadZipDataFromTGZ("./smskeeper/data/zipdata.tgz")

		logger.info("Getting list of classified users...")
		try:
			response = urllib2.urlopen("http://prod.strand.duffyapp.com/smskeeper/classified_users").read()
		except URLError as e:
			logger.info("Could not connect to prod server: %@" % (e))
			response = {"users": []}

		classified_users = json.loads(response)["users"]
		logger.info("Replaying messages for %d users..." % min(len(classified_users), MAX_USERS_TO_SIMULATE))

		message_count = 0
		unknown_count = 0
		unknown_classifications = {}

		testPhoneNumInt = 16505550000
		for user_id in classified_users[:MAX_USERS_TO_SIMULATE]:
			# deactivate the old user, if there is one
			if self.user:
				self.user.state = keeper_constants.STATE_SUSPENDED
				self.user.save()

			logger.info("\nReplaying user %d with testPhoneNumInt: %d" % (user_id, testPhoneNumInt))
			# uncomment temporary for testing
			# setup the user
			# if testPhoneNumInt >= 16505550002:
			# break

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
				logger.info("Could not connect to prod server for messages: %@" % (e))
				messages_response = {"messages": []}

			messages = json.loads(messages_response)["messages"]
			self.setNow(dateMock, parser.parse(messages[0]["added"]))

			# replay them one by one, checking for unknown in each pass
			for message in messages:
				if not message.get("incoming", False):
					continue

				# set the time/state correctly for the message

				message_date = parser.parse(message["added"])
				if self.mockedDate > message_date:
					self.setNow(dateMock, message_date)
				elif self.mockedDate < message_date:
					while self.mockedDate < message_date:
						nextEventDate = self.getNextEventDate()
						# logger.info("dateMock %s message_date %s newTime %s" % (self.mockedDate, message_date, newTime))
						if nextEventDate <= message_date:
							self.setNow(dateMock, nextEventDate)
							# run async jobs
							with patch('smskeeper.sms_util.recordOutput') as mock:
								with patch('common.weather_util.getWeatherPhraseForZip') as weatherMock:
									weatherMock.return_value = "mock forecast"
									async.processDailyDigest()
								async.sendTips()
								async.processAllReminders()
								output = self.getOutput(mock)
								if output != "":
									logger.info(
										"Keeper (%s): %s",
										self.mockedDate.astimezone(self.user.getTimezone()).strftime("%m/%d %H:%M"),
										self.getOutput(mock)
									)
							# nudge the time by a second or we go into an infinite loop
							self.setNow(dateMock, nextEventDate + timedelta(seconds=1))
						else:
							break

				self.setNow(dateMock, message_date)
				# with patch('smskeeper.msg_util.timezoneForZipcode') as mock_tz:
				# 	mock_tz.return_value = "PST"
				with patch('smskeeper.sms_util.recordOutput') as mock:
					cliMsg.msg(self.testPhoneNumber, message["Body"])
					logger.info(
						"%s (%s, %s): %s",
						self.testPhoneNumber,
						self.mockedDate.astimezone(self.user.getTimezone()).strftime("%m/%d %H:%M"),
						self.user.state, message["Body"]
					)
					output = self.getOutput(mock)
					if output != "":
						logger.info("Keeper: %s" % (self.getOutput(mock)))

				message_count += 1
				self.user = User.objects.get(id=self.user.id)
				if self.user.paused:
					unknown_count += 1
					self.user.paused = False
					self.user.save()
					correct_classification = message["classification"]
					class_list = unknown_classifications.get(correct_classification, [])
					message["uid"] = user_id  # pass this through for printing out
					class_list.append(message)
					unknown_classifications[correct_classification] = class_list

				# set the correct classification for the message objct
				lastMessageObject = self.user.getMessages(incoming=True, ascending=False)[0]
				lastMessageObject.classification = message["classification"]
				lastMessageObject.save()

		logger.info(
			"\n\n *** Unknown Rate ***\n"
			+ "%d messages" % message_count
			+ "\n%d unknown" % unknown_count
			+ "\n%.02f unknown rate" % (float(unknown_count) / float(message_count))
			+ "\n"
		)

		logger.info("\n*** Unknown Messages by Classification ***")
		for key in unknown_classifications.keys():
			message_list = unknown_classifications[key]
			logger.info("\n%s: %d messages missed:\n" % (key, len(message_list)))
			for message in message_list:
				logger.info("- %s (%s)" % (message["Body"], message["uid"]))

		self.printMisclassifictions()

	def printMisclassifictions(self):
		logger.info("\n\n******* Accuracy *******")
		truePositivesByClass = {}
		trueNegativesByClass = {}
		falseNegativesByClass = {}
		falsePositivesByClass = {}

		allClasses = map(lambda x: x["value"], Message.Classifications())

		logger.info("All messages count %d" % Message.objects.all().count())
		unclassified_count = 0
		classified_count = 0

		for message in Message.objects.all():
			# skip messages we don't have a manual classification for, messages we explicity said NoCategory
			# for, or unkown messages, which are broken out above
			if (not message.classification
						or message.classification == keeper_constants.CLASS_NONE
						or not message.auto_classification):
				unclassified_count += 1
				continue

			classified_count += 1
			truePositives = truePositivesByClass.get(message.classification, [])
			# falseNegatives[classB] = instances where the correct class was classB, but we thought it was something else
			# falsePositives[classA] = instances where the correct class was something else, but we mistook it for classA
			falseNegativesForClass = falseNegativesByClass.get(message.classification, [])
			falsePositivesForClass = falsePositivesByClass.get(message.auto_classification, [])

			if message.classification == message.auto_classification:
				truePositives.append(message.getBody())
				self.setMessageTrueNegativeForClasses(
					message.getBody(),
					[otherClass for otherClass in allClasses if otherClass != message.classification],
					trueNegativesByClass
				)
			else:
				falseNegativesForClass.append(message.getBody())
				falsePositivesForClass.append(message.getBody())
				self.setMessageTrueNegativeForClasses(
					message.getBody(),
					[otherClass for otherClass in allClasses if (otherClass != message.classification and otherClass != message.auto_classification)],
					trueNegativesByClass
				)

			# set the results dicts based on new results
			truePositivesByClass[message.classification] = truePositives
			falsePositivesByClass[message.auto_classification] = falsePositivesForClass
			falseNegativesByClass[message.classification] = falseNegativesForClass

		logger.info("Unclassified, Unknown, and NoCategory count: %d" % unclassified_count)
		logger.info("Classified messages tested for accuracy: %d" % classified_count)

		allTp = sum(map(lambda arr: len(arr), truePositivesByClass.values()))
		allTn = sum(map(lambda arr: len(arr), trueNegativesByClass.values()))
		allFp = sum(map(lambda arr: len(arr), falsePositivesByClass.values()))
		allFn = sum(map(lambda arr: len(arr), falseNegativesByClass.values()))
		self.printCategorySummary("Overall", allTp, allTn, allFn, allFp)

		for classification in allClasses:
			tp = len(truePositivesByClass.get(classification, []))
			tn = len(trueNegativesByClass.get(classification, []))
			fn = len(falseNegativesByClass.get(classification, []))
			fp = len(falsePositivesByClass.get(classification, []))

			if (tp + fn) == 0:
				logger.info("\nNo examples found for %s.  Skipping." % (classification))
				continue
			self.printCategorySummary(classification, tp, tn, fn, fp)

		logger.info("\n\n*** Misclassified Messages by Classification ***")
		for classification in allClasses:
			self.printMisclassifiedMessagesForClass(classification, falseNegativesByClass, falsePositivesByClass)

	'''
	Metric	    Formula
	Accuracy    (TP + TN) / (TP + TN + FP + FN)
	Precision	TP / (TP + FP)
	Recall	    TP / (TP + FN)
	F1-score	2 x P x R / (P + R)
	'''
	def printCategorySummary(self, classification, tp, tn, fn, fp):
		if (tp + fp) > 0:
			precision = float(tp) / float(tp + fp)
		else:
			precision = 0.0

		if (tp + fn) > 0:
			recall = float(tp) / float(tp + fn)
		else:
			recall = 0.0

		logger.info("\n%s results:" % (classification))
		logger.info(
			"Accuracy %.02f (%d of %d classification decisions are correct)",
			float(tp + tn) / float(tp + tn + fp + fn),
			tp + tn,
			tp + tn + fp + fn
		)
		logger.info(
			"Precision %.02f (%d of %d messages classified as %s were correct)",
			precision,
			tp,
			tp + fp,
			classification
		)
		logger.info(
			"Recall %.02f (%d of %d messages that actually are %s were found)",
			recall,
			tp,
			tp + fn,
			classification
		)

		if (precision + recall) > 0:
			f1 = (2 * precision * recall) / (precision + recall)
		else:
			f1 = 0.0

		logger.info("F1 score: %.02f", f1)

	def printMisclassifiedMessagesForClass(self, classification, falseNegativesByClass, falsePositivesByClass):
		falseNegatives = falseNegativesByClass.get(classification, [])
		falsePositives = falsePositivesByClass.get(classification, [])
		if len(falseNegatives) > 0:
			logger.info("\n%s: messages that should have been interpreted as %s but were not:" % (classification, classification))
			for msg in falseNegatives:
				logger.info(" - %s" % msg)

		if len(falsePositives) > 0:
			logger.info("\n%s: messages that were erroneously interpreted as %s" % (classification, classification))
			for msg in falsePositives:
				logger.info(" - %s" % msg)

	def setMessageTrueNegativeForClasses(self, msg, classes, trueNegativesByClass):
		for otherClass in classes:
			trueNegatives = trueNegativesByClass.get(otherClass, [])
			trueNegatives.append(msg)
			trueNegativesByClass[otherClass] = trueNegatives

	def setupAuthenticatedBrowser(self):
		logger.info("Logging in to prod...")
		self.browser = mechanize.Browser()
		self.browser.open('http://prod.strand.duffyapp.com/admin/login/')
		self.browser.form = self.browser.forms().next()
		self.browser['username'] = 'henry'
		self.browser['password'] = 'duffy'
		self.browser.submit()

	def getNextEventDate(self):
		# figure out when to adjust the clock to, the next todo, next digest, or next tips
		pendingTodos = user_util.pendingTodoEntries(self.user, includeAll=True, after=self.mockedDate)
		if len(pendingTodos) > 0:
			nextReminderDate = pendingTodos[0].remind_timestamp
		else:
			nextReminderDate = self.mockedDate + timedelta(days=30)

		localMockedDate = self.mockedDate.astimezone(self.user.getTimezone())
		nextDigestDate = copy.copy(localMockedDate)
		nextDigestDate = nextDigestDate.replace(
			hour=keeper_constants.TODO_DIGEST_HOUR,
			minute=keeper_constants.TODO_DIGEST_MINUTE,
			second=0
		)
		if nextDigestDate < localMockedDate:  # if the next digest date is in the past, it should be tomorrow
			nextDigestDate += timedelta(days=1)

		# we have the next time events, set the time to the first and simulate events
		times = sorted([nextReminderDate, nextDigestDate])
		return times[0]

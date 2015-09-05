# to run use ./manage.py test smskeeper.scripts.simulateClassifiedMessages

import urllib2
from urllib2 import URLError
from mock import patch

from smskeeper.tests import test_base
import json

from smskeeper import keeper_constants
from smskeeper.models import User
from smskeeper.models import Message
import mechanize

from smskeeper.scripts import importZipdata

from datetime import datetime
from common import date_util
import pytz

from smskeeper.engine import Engine
from smskeeper.chunk import Chunk

from django.conf import settings


# don't do users with UID < 1000, they have hash tags etc in their transcripts
MIN_USER_ID = 1000

CLASSIFIED_MESSAGES_URL = "http://prod.strand.duffyapp.com/smskeeper/classified_messages_feed"

class MyLogger:
	filePath = None
	fileHandle = None

	def __init__(self, filePath, mode='a'):
		self.filePath = filePath
		self.fileHandle = open(filePath, 'w')

	def info(self, formatStr, *args):
		try:
			formatted = formatStr % args
		except:
			formatted = "Error in formatstr: %s" % formatStr
		if type(formatted) == unicode:
			formatted = formatted.encode('utf-8')
		self.fileHandle.write("%s\n" % formatted)

	def finalize(self):
		self.fileHandle.close()

logger = MyLogger("/mnt/log/sim.log", mode='w')
summaryLogger = MyLogger("/mnt/log/sim_summary.log")

MAX_USERS_TO_SIMULATE = 10000


def summaryText(text, *args):
	logger.info(text, *args)
	summaryLogger.info(text, *args)


@patch('common.date_util.utcnow')
class SMSKeeperClassifyMessagesCase(test_base.SMSKeeperBaseCase):
	message_count = 0
	classified_messages = []

	def test_parse_accuracy(self, dateMock):
		logger.info("Starting simulation on %s", datetime.now())
		# self.setupAuthenticatedBrowser()

		logger.info("Importing zip data...")
		importZipdata.loadZipDataFromTGZ("./smskeeper/data/zipdata.tgz")

		logger.info("Getting classified messages...")
		try:
			response = urllib2.urlopen(CLASSIFIED_MESSAGES_URL).read()
		except URLError as e:
			logger.info("Could not connect to prod server: %@" % (e))
			response = {"users": []}

		classified_messages = json.loads(response)

		for message in classified_messages:
			logger.info("Processing message: %s", message)
			self.message_count += 1
			userId = message["user"]
			try:
				user = User.objects.get(id=userId)
			except:
				phone_number = self.phoneNumberForUserId(userId)
				logger.info("Creating user %d with phone_number %s", userId, phone_number)
				user = User.objects.create(phone_number=phone_number)
			self.setUserProps(user, message.get("userSnapshot"))
			# TODO set entries
			# TODO set recent outgoing message classes
			self.scoreMessage(user, message)

		self.printMisclassifictions()

		summaryLogger.finalize()
		logger.finalize()

	def setUserProps(self, user, userSnapshot):
		logger.info("setting props from userSnapshot: %s", userSnapshot)
		if userSnapshot:
			for key in userSnapshot.keys():
				setattr(user, key, userSnapshot.get(key))
		else:
			# default values
			user.productId = keeper_constants.TODO_PRODUCT_ID
			user.state = keeper_constants.STATE_NORMAL
			user.completed_tutorial = True
			dt = date_util.now(pytz.utc)
			user.activated = datetime(day=dt.day, year=dt.year, month=dt.month, hour=dt.hour, minute=dt.minute, second=dt.second).replace(tzinfo=pytz.utc)
			user.signature_num_lines = 0
		user.save()

	def scoreMessage(self, user, message):
		chunk = Chunk(message["body"])
		engine = Engine(Engine.DEFAULT, 0.0)
		processed, classification, actionScores = engine.process(user, chunk, simulate=True)

		# set the correct classification for the message objct
		message["simulated_classification"] = classification
		logger.info("Scored message %s", message)
		self.classified_messages.append(message)

	def phoneNumberForUserId(self, uid):
		return "+1650555" + "%04d" % uid

	def printUnknowns(self):
		summaryText(
			"\n\n *** Unknown Rate ***\n"
			+ "%d messages" % self.message_count
			+ "\n%d unknown" % self.unknown_count
			+ "\n%.02f unknown rate" % (float(self.unknown_count) / float(self.message_count))
			+ "\n"
		)

		logger.info("\n*** Unknown Messages by Classification ***")
		for key in self.unknown_classifications.keys():
			message_list = self.unknown_classifications[key]
			logger.info("\n%s: %d messages missed:\n" % (key, len(message_list)))
			for message in message_list:
				logger.info("- %s (%s)" % (message["Body"], message["uid"]))

	def printMisclassifictions(self):
		summaryText("\n\n******* Accuracy *******")
		truePositivesByClass = {}
		trueNegativesByClass = {}
		falseNegativesByClass = {}
		falsePositivesByClass = {}

		allClasses = map(lambda x: x["value"], keeper_constants.CLASS_MENU_OPTIONS)

		summaryText("All messages count %d" % Message.objects.all().count())
		unclassified_count = 0
		classified_count = 0
		manual_count = 0

		print "len(self.classified_messages): %d" % len(self.classified_messages)
		for message in self.classified_messages:
			if message["manual"] and settings.LOCAL is not True:
				manual_count += 1
				continue

			classified_count += 1
			messageClass = message["classification"]
			simulatedClass = message["simulated_classification"]
			body = message["body"]
			truePositives = truePositivesByClass.get(messageClass, [])
			# falseNegatives[classB] = instances where the correct class was classB, but we thought it was something else
			# falsePositives[classA] = instances where the correct class was something else, but we mistook it for classA
			falseNegativesForClass = falseNegativesByClass.get(messageClass, [])
			falsePositivesForClass = falsePositivesByClass.get(simulatedClass, [])

			if messageClass == simulatedClass:
				truePositives.append(body)
				self.setMessageTrueNegativeForClasses(
					body,
					[otherClass for otherClass in allClasses if otherClass != messageClass],
					trueNegativesByClass
				)
			else:
				falseNegativesForClass.append(body)
				falsePositivesForClass.append(body)
				self.setMessageTrueNegativeForClasses(
					body,
					[otherClass for otherClass in allClasses if (otherClass != messageClass and otherClass != simulatedClass)],
					trueNegativesByClass
				)

			# set the results dicts based on new results
			truePositivesByClass[messageClass] = truePositives
			falsePositivesByClass[simulatedClass] = falsePositivesForClass
			falseNegativesByClass[messageClass] = falseNegativesForClass

		summaryText("Unclassified, Unknown, and NoCategory count: %d" % unclassified_count)
		summaryText("Manual messages ignored: %d" % manual_count)
		summaryText("Classified messages tested for accuracy: %d" % classified_count)

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
				summaryText("\nNo examples found for %s.  Skipping." % (classification))
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
		if tp + tn + fp + fn == 0:
			summaryText("No info for %s" % classification)
			return
		if (tp + fp) > 0:
			precision = float(tp) / float(tp + fp)
		else:
			precision = 0.0

		if (tp + fn) > 0:
			recall = float(tp) / float(tp + fn)
		else:
			recall = 0.0

		summaryText("\n%s results:" % (classification))
		summaryText(
			"Accuracy %.02f (%d of %d classification decisions are correct)",
			float(tp + tn) / float(tp + tn + fp + fn),
			tp + tn,
			tp + tn + fp + fn
		)
		summaryText(
			"Precision %.02f (%d of %d messages classified as %s were correct)",
			precision,
			tp,
			tp + fp,
			classification
		)
		summaryText(
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

		summaryText("F1 score: %.02f", f1)

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

# to run use ./manage.py test smskeeper.scripts.simulateClassifiedMessages

from datetime import datetime
import json
from urllib2 import URLError
import urllib2
import traceback
import pwd
import os

from django.conf import settings
from django.core.serializers.json import DjangoJSONEncoder
import mechanize
from smskeeper import keeper_constants
from smskeeper.engine.engine_harness import EngineSimHarness
from smskeeper.engine import Engine
from smskeeper.engine.smrt_scorer import SmrtScorer
from smskeeper.engine.v1_scorer import V1Scorer
from smskeeper.models import Message
from smskeeper.scripts import importZipdata
from smskeeper.tests import test_base

import subprocess
GIT_REVISION = subprocess.check_output(["git", "describe", "--always"]).replace("\n", "")


# don't do users with UID < 1000, they have hash tags etc in their transcripts
MIN_USER_ID = 1000


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
UNIX_NAME = pwd.getpwuid(os.getuid()).pw_name


def summaryText(text, *args):
	logger.info(text, *args)
	summaryLogger.info(text, *args)


class SMSKeeperSimulationCase(test_base.SMSKeeperBaseCase):
	message_count = 0
	classified_messages = []
	SIMULATION_CONFIGURATION = None
	'''
	SIMULATION_CONFIGURATION shoudl include
	'message_source'
	'sim_type'
	'classified_messages_url'
	'post_results_url'
	'''

	def test_parse_accuracy(self):
		if not self.SIMULATION_CONFIGURATION:
			raise NameError("This is the base simulation class, use a speicific configuration.")

		logger.info("Starting simulation on %s", datetime.now())
		# self.setupAuthenticatedBrowser()

		logger.info("Importing zip data...")
		importZipdata.loadZipDataFromTGZ("./smskeeper/data/zipdata.tgz")

		logger.info("Getting classified messages from %s...", self.SIMULATION_CONFIGURATION['classified_messages_url'])
		try:
			response = urllib2.urlopen(self.SIMULATION_CONFIGURATION['classified_messages_url']).read()
		except URLError as e:
			logger.info("Could not connect to server for messages: %s" % (e))
			response = {"users": []}

		classified_messages = json.loads(response)

		v1Scorer = V1Scorer(Engine.DEFAULT, 0.0)
		smrtScorer = SmrtScorer(Engine.DEFAULT, 0.0, local=True)
		engine = Engine(Engine.DEFAULT, 0.0)
		harness = EngineSimHarness(v1Scorer, smrtScorer, engine)

		for message in classified_messages:
			try:
				if self.SIMULATION_CONFIGURATION['sim_type'] == 'p' and int(message["user"]) < MIN_USER_ID:
					continue
				logger.info("\n Processing message: %s", message)
				self.message_count += 1

				classification, actionsByScore = harness.scoreMessage(message)

				scoresByActionName = dict()
				for score, actions in actionsByScore.iteritems():
					for action in actions:
						scoresByActionName[action.ACTION_CLASS] = score

				message["simulated_classification"] = classification
				message["simulated_scores"] = scoresByActionName
				logger.info("Scored message %s", message)
				self.classified_messages.append(message)
			except Exception as e:
				logger.info("-" * 60)
				logger.info(
					"Error processing message: %s\n*** Exception %s",
					message,
					traceback.format_exc()
				)
				if message in self.classified_messages:
					self.classified_messages.remove(message)

		if len(self.classified_messages) > 0:
			self.uploadClassificationResults()
			self.printMisclassifictions()
		else:
			print "No classified messages, check the /mnt/log/sim.log"

		summaryLogger.finalize()
		logger.finalize()

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

	def uploadClassificationResults(self):
		# create the dicts
		simRun = {
			"username": UNIX_NAME,
			"git_revision": GIT_REVISION,
			"source": self.SIMULATION_CONFIGURATION['message_source'],
			"sim_type": self.SIMULATION_CONFIGURATION['sim_type'],
			"simResults": [],
		}
		for message in self.classified_messages:
			simResult = {}
			simResult["message_classification"] = message["classification"]
			simResult["message_auto_classification"] = message["auto_classification"]
			simResult["message_id"] = message["id"]
			simResult["message_body"] = message["body"]
			simResult["sim_classification"] = message["simulated_classification"]
			simResult["sim_classification_scores_json"] = json.dumps(message["simulated_scores"])
			simRun["simResults"].append(simResult)

		logger.info("\n\n****Uploading results to: %s", self.SIMULATION_CONFIGURATION['post_results_url'])
		req = urllib2.Request(self.SIMULATION_CONFIGURATION['post_results_url'])
		req.add_header('Content-Type', 'application/json')
		try:
			response = urllib2.urlopen(req, json.dumps(simRun, cls=DjangoJSONEncoder))
		except urllib2.HTTPError, error:
			contents = error.read()
			print "Couldn't upload results %s:\n%s" % (error, contents)
		logger.info("Upload response: %s", response)

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

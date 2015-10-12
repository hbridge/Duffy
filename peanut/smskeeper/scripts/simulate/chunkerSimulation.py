# to run use ./manage.py test smskeeper.scripts.simulateClassifiedMessages

import datetime
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
from smskeeper.engine.chunker_engine import ChunkerEngine
from smskeeper.models import Message

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

logger = MyLogger("/mnt/log/chunker_sim.log", mode='w')
summaryLogger = MyLogger("/mnt/log/chunker_sim_summary.log")

MAX_USERS_TO_SIMULATE = 10000
UNIX_NAME = pwd.getpwuid(os.getuid()).pw_name


def summaryText(text, *args):
	logger.info(text, *args)
	summaryLogger.info(text, *args)


class SMSKeeperChunkerSimulationCase(test_base.SMSKeeperBaseCase):
	message_count = 0
	classified_messages = []
	SIMULATION_CONFIGURATION = None
	correct = []
	fn = []
	fp = []
	'''
	SIMULATION_CONFIGURATION shoudl include
	'message_source'
	'sim_type'
	'classified_messages_url'
	'post_results_url'
	'''

	prodDataFilename = "prod_classified_messages.json"

	def modification_date(self, filename):
		t = os.path.getmtime(filename)
		return datetime.datetime.fromtimestamp(t)

	def test_chunk_accuracy(self):
		if not self.SIMULATION_CONFIGURATION:
			raise NameError("This is the base simulation class, use a speicific configuration.")

		logger.info("\n\nStarting chunker test on %s", datetime.datetime.now())
		# self.setupAuthenticatedBrowser()

		logger.info("Getting compound messages from %s...", self.SIMULATION_CONFIGURATION['classified_messages_url'])
		try:
			response = urllib2.urlopen(self.SIMULATION_CONFIGURATION['classified_messages_url']).read()
		except URLError as e:
			logger.info("Could not connect to server for messages: %s" % (e))
			response = {"users": []}

		compound_messages = json.loads(response)

		count = 0
		simulatedCount = 0
		for message in compound_messages:
			count += 1
			print "Starting message... %s / %s" % (count, len(compound_messages))

			try:
				if self.SIMULATION_CONFIGURATION['sim_type'] == 'p' and int(message["user"]) < MIN_USER_ID:
					continue
				chunkerEngine = ChunkerEngine(message['body'])
				indices = chunkerEngine.getChunkStartIndices()
				message['sim_indices'] = indices if indices else []
				actualIndices = json.loads(message['statement_bounds_json'])
				if 0 not in actualIndices:
					actualIndices = [0] + actualIndices
					message['statement_bounds_json'] = json.dumps(actualIndices)
				print "indices %s actualIndices %s" % (indices, actualIndices)
				if indices != actualIndices:
					if len(indices) < len(actualIndices):
						self.fn.append(message)
					else:
						self.fp.append(message)
				else:
					self.correct.append(message)
				simulatedCount += 1

			except Exception as e:
				logger.info("-" * 60)
				logger.info(
					"Error processing message: %s\n*** Exception %s",
					message,
					traceback.format_exc()
				)
				if message in self.classified_messages:
					self.classified_messages.remove(message)

		if simulatedCount > 0:
			# self.uploadClassificationResults()
			summaryText("Summary for run @%s at %s", GIT_REVISION, datetime.datetime.now())
			self.printResults()
		else:
			print "No classified messages, check the /mnt/log/sim.log"

		summaryLogger.finalize()
		logger.finalize()

	def printResults(self):
		self.printMessageResultArray("CORRECT", self.correct)
		self.printMessageResultArray("WRONG", self.fp)
		self.printMessageResultArray("MISSED CHUNK", self.fn)

	def printMessageResultArray(self, header, array):
		summaryText("\n%s" % header)
		summaryText("*" * 60)
		summaryText("\n".join(map(lambda message: (
			message["body"] + "\n   Engine: %s\n   Actual: %s" % (
				message['sim_indices'],
				message['statement_bounds_json']
			)
		), array)))

	def setupAuthenticatedBrowser(self):
		logger.info("Logging in to prod...")
		self.browser = mechanize.Browser()
		self.browser.open('http://prod.strand.duffyapp.com/admin/login/')
		self.browser.form = self.browser.forms().next()
		self.browser['username'] = 'henry'
		self.browser['password'] = 'duffy'
		self.browser.submit()

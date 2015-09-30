#!/usr/bin/python

# To Run:  python smskeeper/learning/createFeaturesFile.py
import sys
import os
import json
import datetime
import urllib2
import csv
from urllib2 import URLError

import logging

parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0], "..")

if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.engine.engine_harness import EngineSimHarness
from smskeeper import keeper_constants

logger = logging.getLogger(__name__)

# don't do users with UID < 1000, they have hash tags etc in their transcripts
MIN_USER_ID = 1000


class FeatureGenerator():
	def getClassCode(self, classification):
		for entry in keeper_constants.CLASS_MENU_OPTIONS:
			if entry["value"] == classification:
				return entry["code"]
		print "coudlnt' find %s" % classification
		exit()
		return -1

	CONFIGURATION = {
		'classified_messages_url': "http://prod.strand.duffyapp.com/smskeeper/classified_messages_feed",
	}

	messageCount = 0

	def generate(self):
		logger.info("Starting simulation on %s", datetime.datetime.now())
		# self.setupAuthenticatedBrowser()

		logger.info("Getting classified messages from %s...", self.CONFIGURATION['classified_messages_url'])
		try:
			response = urllib2.urlopen(self.CONFIGURATION['classified_messages_url']).read()
		except URLError as e:
			logger.info("Could not connect to server for messages: %s" % (e))
			response = {"users": []}

		classified_messages = json.loads(response)

		harness = EngineSimHarness()
		parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0])
		outputFileLoc = parentPath + keeper_constants.LEARNING_DIR_LOC + 'features.csv'
		headersOutputFileLoc = parentPath + keeper_constants.LEARNING_DIR_LOC + 'headers.csv'

		with open(outputFileLoc, 'w') as csvfile:
			writer = csv.writer(csvfile, delimiter=',', quotechar='|', quoting=csv.QUOTE_MINIMAL)

			headersOut = False
			headers = list()

			for message in classified_messages:
				if int(message["user"]) < MIN_USER_ID:
					continue
				if "userSnapshot" not in message:
					continue
				#if not message["userSnapshot"]:
				#	continue

				logger.info("\n Processing message: %s", message)
				self.messageCount += 1

				featuresDict = harness.getFeatures(message)

				if not headersOut:
					headersOut = True

					for k, v in featuresDict.iteritems():
						headers.append(k)
					l = list(headers)
					l.append("classification")
					writer.writerow(l)

					# output the headers
					with open(headersOutputFileLoc, 'w') as out:
						headersWriter = csv.writer(out, delimiter=',')
						headersWriter.writerow(l)

				data = [featuresDict[h] for h in headers]

				data.append(self.getClassCode(message['classification']))
				writer.writerow(data)






def main(argv):
	print "Starting..."

	generator = FeatureGenerator()

	generator.generate()

	print "Donezo!"

if __name__ == "__main__":
	logging.basicConfig(filename='/mnt/log/createFeatures.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	main(sys.argv[1:])

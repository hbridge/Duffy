import logging
import operator
import urllib2
import json
import os
import csv
import urllib
from urllib2 import URLError

from smskeeper import chunk_features

from smskeeper import keeper_constants

from sklearn.externals import joblib

logger = logging.getLogger(__name__)


class LocalSmrtScorer():
	model = None
	headers = None

	def __init__(self):
		logger.info("Loading model for SMRT")
		parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0])
		modelPath = parentPath + keeper_constants.LEARNING_DIR_LOC + 'model'
		logger.info("Using model path: %s " % modelPath)
		try:
			self.model = joblib.load(modelPath)
		except Exception, e:
			logger.info("Got exception %s loading model" % e)

		headersFileLoc = parentPath + keeper_constants.LEARNING_DIR_LOC + 'headers.csv'
		logger.info("Using headers path: %s " % headersFileLoc)

		with open(headersFileLoc, 'r') as csvfile:
			logger.info("Successfully read file")
			reader = csv.reader(csvfile, delimiter=',')
			done = False
			for row in reader:
				if not done:
					self.headers = row
				done = True

		logger.info("Done loading model")

	def score(self, userId, msg, featuresDict):
		logger.info("User %s: Scoring msg '%s'" % (userId, msg))

		data = list()
		for header in self.headers[:-2]:
			data.append(featuresDict[header])

		scores = self.model.predict_proba(data)
		scoresByActionName = self.getScoresByActionName(scores)

		for actionName, score in sorted(scoresByActionName.items(), key=operator.itemgetter(1), reverse=True):
			logger.info("User %s: SMRT Action %s got score %s" % (userId, actionName, score))

		return scoresByActionName

	def getActionNameFromCode(self, code):
		for entry in keeper_constants.CLASS_MENU_OPTIONS:
			if entry["code"] == code:
				return entry["value"]
		return None

	def getScoresByActionName(self, scores):
		result = dict()
		nparr = scores[0]

		for code in range(len(nparr)):
			actionName = self.getActionNameFromCode(code)
			if actionName:
				score = nparr[code]
				result[actionName] = float("{0:.2f}".format(score))
		return result


class SmrtScorer():
	actionList = None
	minScore = 0.0

	smrtServerPort = "7995"

	def __init__(self, actionList, minScore, local=False):
		self.actionList = actionList
		self.minScore = minScore
		self.local = local

		if local:
			self.model = LocalSmrtScorer()

	def getActionByName(self, actionName):
		for action in self.actionList:
			if action.ACTION_CLASS == actionName:
				return action
		return None

	def score(self, user, chunk, overrideClassification=None):
		logger.info("User %s: Starting processing of chunk: '%s'" % (user.id, chunk.originalText))
		actionsByScore = dict()

		features = chunk_features.ChunkFeatures(chunk, user)
		featuresDict = chunk_features.getFeaturesDict(features)

		if self.local:
			scoresByActionName = self.model.score(user.id, chunk.originalText, featuresDict)
		else:
			# converting back to utf-8 for urllib
			params = {"msg": unicode(chunk.originalText).encode('utf-8')}

			params["userId"] = str(user.id)
			params["featuresDict"] = json.dumps(featuresDict)

			smrtServerUrl = "http://localhost:%s/?%s" % (self.smrtServerPort, urllib.urlencode(params))

			logger.debug("User %s: Hitting smrtServer url: %s" % (user.id, smrtServerUrl))

			try:
				smrtServerResult = urllib2.urlopen(smrtServerUrl).read()
			except URLError as e:
				logger.error("Could not connect to SmrtServer: %s" % (e.strerror))
				return actionsByScore

			logger.debug("User %s: Got smrtServer response: %s" % (user.id, smrtServerResult))

			results = json.loads(smrtServerResult)
			scoresByActionName = results["scores"]

		# Fill in scoreByAction
		for actionName, score in sorted(scoresByActionName.items(), key=operator.itemgetter(1), reverse=True):
			action = self.getActionByName(actionName)
			if action:
				logger.info("User %s: Action %s got score %s" % (user.id, action.ACTION_CLASS, score))

				if score not in actionsByScore:
					actionsByScore[score] = list()
				actionsByScore[score].append(action)

		return actionsByScore

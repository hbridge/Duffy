import logging
import operator
import os
import csv

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
			if header not in featuresDict:
				print "%s not found in %s" % (header, featuresDict)
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

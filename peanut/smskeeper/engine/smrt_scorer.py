import logging
import operator
import urllib2
import json
import urllib
from urllib2 import URLError


logger = logging.getLogger(__name__)


class SmrtScorer():
	actionList = None
	minScore = 0.0

	smrtServerPort = "7995"

	def __init__(self, actionList, minScore):
		self.actionList = actionList
		self.minScore = minScore

	def getActionByName(self, actionName):
		for action in self.actionList:
			if action.ACTION_CLASS == actionName:
				return action
		return None

	def score(self, user, chunk, overrideClassification=None):
		logger.info("User %s: Starting processing of chunk: '%s'" % (user.id, chunk.originalText))
		actionsByScore = dict()

		# converting back to utf-8 for urllib
		params = {"msg": unicode(chunk.originalText).encode('utf-8')}

		params["userId"] = str(user.id)

		smrtServerUrl = "http://localhost:%s/?%s" % (self.smrtServerPort, urllib.urlencode(params))

		logger.debug("User %s: Hitting smrtServer url: %s" % (user.id, smrtServerUrl))

		try:
			smrtServerResult = urllib2.urlopen(smrtServerUrl).read()
		except URLError as e:
			logger.error("Could not connect to SmrtServer: %s" % (e.strerror))
			return actionsByScore

		logger.debug("User %s: Got smrtServer response: %s" % (user.id, smrtServerResult))

		results = json.loads(smrtServerResult)
		actionNamesByScore = results["scores"]

		# Fill in scoreByAction
		for actionName, score in sorted(actionNamesByScore.items(), key=operator.itemgetter(1), reverse=True):
			action = self.getActionByName(actionName)
			if action:
				logger.info("User %s: Action %s got score %s" % (user.id, action.ACTION_CLASS, score))

				if score not in actionsByScore:
					actionsByScore[score] = list()
				actionsByScore[score].append(action)

		return actionsByScore

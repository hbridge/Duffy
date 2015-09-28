import logging
import operator
import urllib2
import json
import urllib
from urllib2 import URLError
import pickle
import string
import hashlib

from smskeeper import chunk_features
from smskeeper.engine.local_smrt_scorer import LocalSmrtScorer
from common import date_util
from django.core.cache import cache
from django.conf import settings

logger = logging.getLogger(__name__)


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

	def getCacheKey(self, chunk, user):
		date = date_util.unixTime(date_util.now())
		txt = filter(lambda x: x in string.printable, chunk.normalizedText())
		key = "smrtscorer %s %s %s" % (date, user.getTimezone(), txt)
		return hashlib.md5(key.encode()).hexdigest()

	def score(self, user, chunk, overrideClassification=None):
		logger.info("User %s: Starting processing of chunk: '%s'" % (user.id, chunk.originalText))
		actionsByScore = dict()

		if settings.USE_CACHE:
			cacheResult = cache.get(self.getCacheKey(chunk, user))
			if cacheResult:
				result = pickle.loads(cacheResult)
				logger.debug("User %s: Found cache hit in SmrtScorer, returning %s" % (user.id, result))
				return result

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
				logger.info("User %s: SMRT Action %s got score %s" % (user.id, action.ACTION_CLASS, score))

				if score not in actionsByScore:
					actionsByScore[score] = list()
				actionsByScore[score].append(action)

		if settings.USE_CACHE:
			cache.set(self.getCacheKey(chunk, user), pickle.dumps(actionsByScore))

		return actionsByScore

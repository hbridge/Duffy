import logging
import operator


logger = logging.getLogger(__name__)


class SmrtScorer():
	actionList = None
	minScore = 0.0

	def __init__(self, actionList, minScore):
		self.actionList = actionList
		self.minScore = minScore

	def score(self, user, chunk, overrideClassification=None):
		logger.info("User %s: Starting processing of chunk: '%s'" % (user.id, chunk.originalText))
		actionsByScore = dict()

		# Make http request

		# Fill in scoreByAction

		for score, actions in sorted(actionsByScore.items(), key=operator.itemgetter(0), reverse=True):
			for action in actions:
				logger.info("User %s: Action %s got score %s" % (user.id, action.ACTION_CLASS, score))

		return actionsByScore

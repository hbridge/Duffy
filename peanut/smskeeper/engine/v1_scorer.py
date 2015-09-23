import logging
import operator


logger = logging.getLogger(__name__)


class V1Scorer():
	actionList = None
	minScore = 0.0

	def __init__(self, actionList, minScore):
		self.actionList = actionList
		self.minScore = minScore

	def score(self, user, chunk, overrideClassification=None):
		logger.info("User %s: Starting processing of chunk: '%s'" % (user.id, chunk.originalText))
		actionsByScore = dict()
		if not overrideClassification:
			for action in self.actionList:
				score = action.getScore(chunk, user)

				if score not in actionsByScore:
					actionsByScore[score] = list()

				actionsByScore[score].append(action)
		else:
			logger.info("User %s: Action class overridden to %s" % (user.id, overrideClassification))
			for action in self.actionList:
				if action.ACTION_CLASS == overrideClassification:
					actionsByScore[score] = [action]
					break

		for score, actions in sorted(actionsByScore.items(), key=operator.itemgetter(0), reverse=True):
			for action in actions:
				logger.info("User %s: Action %s got score %s" % (user.id, action.ACTION_CLASS, score))

		return actionsByScore

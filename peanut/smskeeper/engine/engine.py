import logging
import collections
import operator

from smskeeper import keeper_constants
from smskeeper.chunk import Chunk
from smskeeper.engine.stop import StopAction
from smskeeper.engine.fetch_weather import FetchWeatherAction
from smskeeper.engine.question import QuestionAction
from smskeeper.engine.nicety import NicetyAction
from smskeeper.engine.silent_nicety import SilentNicetyAction
from smskeeper.engine.help import HelpAction
from smskeeper.engine.change_setting import ChangeSettingAction
from smskeeper.engine.frustration import FrustrationAction
from smskeeper.engine.fetch_digest import FetchDigestAction
from smskeeper.engine.changetime_most_recent import ChangetimeMostRecentAction
from smskeeper.engine.changetime_specific import ChangetimeSpecificAction
from smskeeper.engine.create_todo import CreateTodoAction
from smskeeper.engine.complete_todo_most_recent import CompleteTodoMostRecentAction
from smskeeper.engine.complete_todo_specific import CompleteTodoSpecificAction
from smskeeper.engine.survey_response import SurveyResponseAction
from smskeeper.engine.jokes import JokeAction

logger = logging.getLogger(__name__)


class Engine:
	actionList = None
	minScore = 0.0

	DEFAULT = [StopAction(), FetchWeatherAction(), QuestionAction(), NicetyAction(), SilentNicetyAction(), HelpAction(), ChangeSettingAction(), FrustrationAction(), FetchDigestAction(), ChangetimeMostRecentAction(), ChangetimeSpecificAction(), CreateTodoAction(), CompleteTodoMostRecentAction(), CompleteTodoSpecificAction(), SurveyResponseAction(), JokeAction()]
	TUTORIAL_BASIC = [StopAction(), QuestionAction(), NicetyAction(), SilentNicetyAction(), HelpAction(), FrustrationAction()]
	TUTORIAL_STEP_2 = [ChangetimeMostRecentAction(), ChangetimeSpecificAction(), CreateTodoAction(tutorial=True)]

	def __init__(self, actionList, minScore):
		self.actionList = actionList
		self.minScore = minScore

	def process(self, user, msgs):
		# if the user
		# TODO when we implement start in the engine this check needs to move
		if user.state == keeper_constants.STATE_STOPPED:
			return False, None

		if not isinstance(msgs, list):
			msgs = [msgs]

		if len(msgs) == 1:
			msg = msgs[0]
		else:
			msg = '\n'.join(msgs)

		chunk = Chunk(msg)

		logger.info("User %s: Starting processing of chunk: '%s'" % (user.id, chunk.originalText))

		actionsByScore = dict()

		for action in self.actionList:
			score = action.getScore(chunk, user)
			if score not in actionsByScore:
				actionsByScore[score] = list()
			actionsByScore[score].append(action)

		sortedActionsByScore = collections.OrderedDict(sorted(actionsByScore.items(), reverse=True))
		actionScores = self.getActionScores(sortedActionsByScore)

		for action, score in sorted(actionScores.items(), key=operator.itemgetter(1), reverse=True):
			logger.info("User %s: Action %s got score %s" % (user.id, action, score))

		for score, actions in sortedActionsByScore.iteritems():

			if score > self.minScore:
				if len(actions) > 1:
					actions = self.tieBreakActions(actions)

				# Pick the first one after sorting
				# Later on we might want to look at the 'processed' return code
				action = actions[0]
				logger.info("User %s: I think '%s' is a %s command" % (user.id, msg, action.ACTION_CLASS))
				processed = action.execute(chunk, user)

				return processed, action.ACTION_CLASS, actionScores

		return False, keeper_constants.CLASS_UNKNOWN, actionScores

	def tieBreakActions(self, actions):
		sortedActions = list()
		actionOrder = [StopAction, FetchWeatherAction, HelpAction, NicetyAction, SilentNicetyAction, FetchDigestAction, JokeAction, ChangeSettingAction, SurveyResponseAction, ChangetimeSpecificAction, ChangetimeMostRecentAction, CompleteTodoSpecificAction, CompleteTodoMostRecentAction, CreateTodoAction, QuestionAction, FrustrationAction]
		for cls in actionOrder:
			for action in actions:
				if action.__class__ == cls:
					sortedActions.append(action)
		return sortedActions

		raise NameError("Couldn't tie break")

	def getActionScores(self, sortedActionsByScore):
		result = dict()
		for score, actions in sortedActionsByScore.iteritems():
			for action in actions:
				result[action.ACTION_CLASS] = score
		return result

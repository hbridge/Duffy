import logging
import collections
import operator

from smskeeper import keeper_constants
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
from smskeeper.engine.tip_question_response import TipQuestionResponseAction
from smskeeper.engine.share_reminder import ShareReminderAction
from smskeeper.engine.jokes import JokeAction

logger = logging.getLogger(__name__)


class Engine:
	actionList = None
	minScore = 0.0

	DEFAULT = ([
		StopAction(),
		FetchWeatherAction(),
		QuestionAction(),
		NicetyAction(),
		SilentNicetyAction(),
		HelpAction(),
		ChangeSettingAction(),
		FrustrationAction(),
		FetchDigestAction(),
		ChangetimeMostRecentAction(),
		ChangetimeSpecificAction(),
		CreateTodoAction(),
		CompleteTodoMostRecentAction(),
		CompleteTodoSpecificAction(),
		TipQuestionResponseAction(),
		JokeAction(),
		ShareReminderAction()
	])
	TUTORIAL_BASIC = ([
		StopAction(),
		QuestionAction(),
		NicetyAction(),
		SilentNicetyAction(),
		HelpAction(),
		FrustrationAction()
	])
	TUTORIAL_STEP_2 = ([
		ChangetimeMostRecentAction(),
		ChangetimeSpecificAction(),
		CreateTodoAction(tutorial=True)
	])

	def __init__(self, actionList, minScore):
		self.actionList = actionList
		self.minScore = minScore

	def process(self, user, chunk, actionsByScore, overrideClassification=None, simulate=False):
		# TODO when we implement start in the engine this check needs to move
		if user.state == keeper_constants.STATE_STOPPED:
			return False, None

		for score, actions in sorted(actionsByScore.items(), key=operator.itemgetter(0), reverse=True):
			if score > self.minScore:
				if len(actions) > 1:
					actions = self.tieBreakActions(actions)

				# Pick the first one after sorting
				# Later on we might want to look at the 'processed' return code
				for action in actions:
					logger.info("User %s: I think '%s' is a %s command...executing" % (user.id, chunk.originalText, action.ACTION_CLASS))
					if not simulate:
						processed = action.execute(chunk, user)
					else:
						processed = True

					if processed:
						logger.info("User %s: Successfully processed '%s' as a %s command" % (user.id, chunk.originalText, action.ACTION_CLASS))
						return True, action.ACTION_CLASS

		return False, keeper_constants.CLASS_UNKNOWN

	def tieBreakActions(self, actions):
		sortedActions = list()
		actionOrder = [StopAction, FetchWeatherAction, HelpAction, NicetyAction, SilentNicetyAction, FetchDigestAction, JokeAction, ChangeSettingAction, TipQuestionResponseAction, ChangetimeSpecificAction, ChangetimeMostRecentAction, CompleteTodoSpecificAction, CompleteTodoMostRecentAction, CreateTodoAction, QuestionAction, FrustrationAction]
		for cls in actionOrder:
			for action in actions:
				if action.__class__ == cls:
					sortedActions.append(action)
		return sortedActions

		raise NameError("Couldn't tie break")

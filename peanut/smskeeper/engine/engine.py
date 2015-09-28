import logging
import operator
import json

from smskeeper import keeper_constants
from smskeeper.engine.actions.stop import StopAction
from smskeeper.engine.actions.fetch_weather import FetchWeatherAction
from smskeeper.engine.actions.question import QuestionAction
from smskeeper.engine.actions.nicety import NicetyAction
from smskeeper.engine.actions.silent_nicety import SilentNicetyAction
from smskeeper.engine.actions.help import HelpAction
from smskeeper.engine.actions.change_setting import ChangeSettingAction
from smskeeper.engine.actions.frustration import FrustrationAction
from smskeeper.engine.actions.fetch_digest import FetchDigestAction
from smskeeper.engine.actions.changetime_most_recent import ChangetimeMostRecentAction
from smskeeper.engine.actions.changetime_specific import ChangetimeSpecificAction
from smskeeper.engine.actions.create_todo import CreateTodoAction
from smskeeper.engine.actions.complete_todo_most_recent import CompleteTodoMostRecentAction
from smskeeper.engine.actions.complete_todo_specific import CompleteTodoSpecificAction
from smskeeper.engine.actions.tip_question_response import TipQuestionResponseAction
from smskeeper.engine.actions.share_reminder import ShareReminderAction
from smskeeper.engine.actions.jokes import JokeAction
from smskeeper.chunk import Chunk

logger = logging.getLogger(__name__)

USE_SMRT = False


class Engine:
	actionList = None
	minScore = 0.0
	tutorial = False

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

	def __init__(self, actionList, minScore, tutorial=False):
		self.actionList = actionList
		self.minScore = minScore
		self.tutorial = tutorial

	def process(self, user, chunk, actions, overrideClassification=None, simulate=False):
		# TODO when we implement start in the engine this check needs to move
		if user.state == keeper_constants.STATE_STOPPED:
			return False, None

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

	# These functions don't really belong here, could move more to a scorer
	def tieBreakActions(self, actions):
		sortedActions = list()
		actionOrder = [StopAction, FetchWeatherAction, HelpAction, NicetyAction, SilentNicetyAction, FetchDigestAction, JokeAction, ChangeSettingAction, TipQuestionResponseAction, ChangetimeSpecificAction, ChangetimeMostRecentAction, CompleteTodoSpecificAction, CompleteTodoMostRecentAction, CreateTodoAction, QuestionAction, FrustrationAction]
		for cls in actionOrder:
			for action in actions:
				if action.__class__ == cls:
					sortedActions.append(action)
		return sortedActions

		raise NameError("Couldn't tie break")

	def getActionByName(self, actionName):
		for action in self.actionList:
			if action.ACTION_CLASS == actionName:
				return action
		return None

	def getBestActions(self, user, chunk, v1actionsByScore, smrtActionsByScore):
		result = list()
		if self.tutorial:
			for score, actions in sorted(v1actionsByScore.items(), key=operator.itemgetter(0), reverse=True):
				if score >= self.minScore:
					if len(actions) > 1:
						actions = self.tieBreakActions(actions)
					result.extend(actions)
					break
		else:
			# Look through past messages of this user to find an exact match that has been classified
			# If found, put that action first
			pastMsgs = user.getPastIncomingMsgs()

			for msg in pastMsgs:
				content = json.loads(msg.msg_json)
				tmpChunk = Chunk(content["Body"])
				if "Body" in content and tmpChunk.normalizedText() == chunk.normalizedText() and msg.classification:
					action = self.getActionByName(msg.classification)
					if action:
						logger.info("User %s: In getBestActions, found an identical match to msg %s so prioritizing class %s" % (user.id, msg.id, msg.classification))
						result.append(action)
						return result

			if USE_SMRT:
				for score, actions in sorted(smrtActionsByScore.items(), key=operator.itemgetter(0), reverse=True):
					#if score >= .3:
					result.extend(actions)


			foundV1 = False
			for score, actions in sorted(v1actionsByScore.items(), key=operator.itemgetter(0), reverse=True):
				if score > self.minScore:
					if len(actions) > 1:
						actions = self.tieBreakActions(actions)


					#if score >= .8:
					#	result = actions + result
					#else:
					result.extend(actions)

					foundV1 = True
					break

			# Exception case:
			# smrt really likes to do createtodo on unknown things.  So if v1 says unknown
			# and smrt says create, treat as unknown
			if len(result) > 0 and result[0].ACTION_CLASS == "createtodo" and not foundV1:
				result = list()

			# Temporary hack:
			# If old engine doesn't find anything, then ignore smrt engine
			if not foundV1:
				result = list()

		logger.debug("User %s: in getBestActions, final actions: %s" % (user.id, [x.ACTION_CLASS for x in result]))
		return result

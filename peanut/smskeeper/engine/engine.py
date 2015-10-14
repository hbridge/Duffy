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

USE_SMRT = True


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

	def process(self, user, chunk, features, actions, overrideClassification=None, simulate=False):
		# TODO when we implement start in the engine this check needs to move
		if user.state == keeper_constants.STATE_STOPPED:
			return False, None

		# Pick the first one after sorting
		# Later on we might want to look at the 'processed' return code
		for i, action in enumerate(actions):
			logger.info("User %s: I think '%s' is a %s command...executing" % (user.id, chunk.originalText, action.ACTION_CLASS))
			if not simulate:
				if i < len(actions) - 1:
					user.nextAction = actions[i + 1]
				processed = action.execute(chunk, user, features)
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
				body = msg.getBody()
				tmpChunk = Chunk(body)
				if body and tmpChunk.normalizedText() == chunk.normalizedText() and msg.classification:
					action = self.getActionByName(msg.classification)
					if action:
						logger.info("User %s: In getBestActions, found an identical match to msg %s so prioritizing class %s" % (user.id, msg.id, msg.classification))
						result.append(action)
						return result

			smrtScoresByActionName = dict()
			topSmrtScore = 0
			if USE_SMRT:
				for score, actions in sorted(smrtActionsByScore.items(), key=operator.itemgetter(0), reverse=True):
					result.extend(actions)

					for action in actions:
						smrtScoresByActionName[action.ACTION_CLASS] = score

					if score > topSmrtScore:
						topSmrtScore = score
			if len(result) > 0:
				topSmrtAction = result[0].ACTION_CLASS
			else:
				topSmrtAction = None

			foundV1 = False
			v1scoresByActionName = dict()
			topV1Score = 0
			v1Actions = list()
			for score, actions in sorted(v1actionsByScore.items(), key=operator.itemgetter(0), reverse=True):
				if score > self.minScore:
					if len(actions) > 1:
						actions = self.tieBreakActions(actions)

					result.extend(actions)
					v1Actions.extend(actions)
					foundV1 = True

				if score > topV1Score:
					topV1Score = score

				for action in actions:
					v1scoresByActionName[action.ACTION_CLASS] = score

			if len(v1Actions) > 0:
				topV1Action = v1Actions[0].ACTION_CLASS
			else:
				topV1Action = None

			if USE_SMRT:
				# If v1 really thinks its a nicety, go with that
				if (topV1Action and topV1Action == keeper_constants.CLASS_NICETY
								and v1scoresByActionName[keeper_constants.CLASS_NICETY] > .9):
					result = v1Actions
				# If v1 really thinks is a shared reminder, go with that
				elif (topV1Action and topV1Action == keeper_constants.CLASS_SHARE_REMINDER
										and v1scoresByActionName[keeper_constants.CLASS_SHARE_REMINDER] > .9):
					result = v1Actions
				# If v1 thinks is a tip question response and smrt doesn't have a good number, go with v1
				elif (topV1Action and topV1Action == keeper_constants.CLASS_TIP_QUESTION_RESPONSE
										and v1scoresByActionName[keeper_constants.CLASS_TIP_QUESTION_RESPONSE] >= .6
										and topSmrtScore < .5):
					result = v1Actions
				# If SMRT says "create":
				#   if v1 says tip question response or change settings, then go with v1
				#   if v1 says nothing...then do nothing
				elif topSmrtAction == "createtodo":
					if v1scoresByActionName[keeper_constants.CLASS_TIP_QUESTION_RESPONSE] >= .7:
						result = [self.getActionByName(keeper_constants.CLASS_TIP_QUESTION_RESPONSE)] + result
					elif v1scoresByActionName[keeper_constants.CLASS_CHANGE_SETTING] >= .9:
						result = [self.getActionByName(keeper_constants.CLASS_CHANGE_SETTING)] + result
					elif v1scoresByActionName[keeper_constants.CLASS_CHANGETIME_SPECIFIC] >= .8:
						result = [self.getActionByName(keeper_constants.CLASS_CHANGETIME_SPECIFIC)] + result
					elif topV1Action == keeper_constants.CLASS_QUESTION:
						result = [self.getActionByName(keeper_constants.CLASS_QUESTION)] + result
					elif not foundV1:
						result = list()
				# If SMRT says "nicety":
				#   if v1 says its def not a nicety, then ignore smrt's first guess
				#   if v1 says its a joke, frustration or stop go with that
				elif topSmrtAction == keeper_constants.CLASS_NICETY:
					if (topV1Action and (topV1Action == keeper_constants.CLASS_QUESTION or
									topV1Action == keeper_constants.CLASS_FRUSTRATION or
									topV1Action == keeper_constants.CLASS_JOKE)):
						result = v1Actions
					elif (smrtScoresByActionName[keeper_constants.CLASS_NICETY] < .6 and
											v1scoresByActionName[keeper_constants.CLASS_NICETY] == 0 and
											v1scoresByActionName[keeper_constants.CLASS_SILENT_NICETY] == 0):
						result = result[1:]
				# If SMRT says "silent-nicety"
				#    if v1 says stop or fetch digest, go with that
				elif topSmrtAction == keeper_constants.CLASS_SILENT_NICETY:
					if (topV1Action and (topV1Action == keeper_constants.CLASS_STOP or
									topV1Action == keeper_constants.CLASS_FETCH_DIGEST)):
						result = v1Actions
				# If SMRT says "changetime-most-recent"
				#    if theres no entries, then goto next best one
				elif (topSmrtAction == keeper_constants.CLASS_CHANGETIME_MOST_RECENT or
										topSmrtAction == keeper_constants.CLASS_CHANGETIME_SPECIFIC or
										topSmrtAction == keeper_constants.CLASS_COMPLETE_TODO_MOST_RECENT or
										topSmrtAction == keeper_constants.CLASS_COMPLETE_TODO_SPECIFIC):
					if len(user.getActiveEntries()) == 0:
						# This is here for the simulator which sets this attribute.
						#    if we don't have a snapshot, just go with the default (don't skip first entry)
						if hasattr(user, "hasSnapshot"):
							if user.hasSnapshot:
								result = result[1:]
						else:
							result = result[1:]
				elif topSmrtAction == keeper_constants.CLASS_STOP:
					if v1scoresByActionName[keeper_constants.CLASS_STOP] == 0:
						result = result[1:]

				# If SMRT isn't that confident and v1 is, go with v1
				if len(result) > 0 and (smrtScoresByActionName[result[0].ACTION_CLASS] < .35):
					if topV1Score >= .5:
						result = v1Actions
					else:
						result = list()

		logger.debug("User %s: in getBestActions, final actions: %s" % (user.id, [x.ACTION_CLASS for x in result]))
		return result

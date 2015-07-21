import logging

from smskeeper import msg_util
from smskeeper import keeper_constants
from smskeeper import actions
from smskeeper.chunk import Chunk
from smskeeper.engine.stop import StopAction
from smskeeper.engine.fetch_weather import FetchWeatherAction
from smskeeper.engine.question import QuestionAction
from smskeeper.engine.nicety import NicetyAction
from smskeeper.engine.silent_nicety import SilentNicetyAction
from smskeeper.engine.help import HelpAction
from smskeeper.engine.change_setting import ChangeSettingAction

logger = logging.getLogger(__name__)

ENGINE_ACTIONS = [StopAction(), FetchWeatherAction(), QuestionAction(), NicetyAction(), SilentNicetyAction(), HelpAction(), ChangeSettingAction()]


class Engine:
	def process(self, user, msg, requestDict, keeperNumber):
		# if the user
		# TODO when we implement start in the engine this check needs to move
		if user.state == keeper_constants.STATE_STOPPED:
			return False, None

		chunk = Chunk(msg)
		actionScores = map(lambda action: action.getScore(chunk, user), ENGINE_ACTIONS)
		bestActions = []
		bestScore = 0.0
		for i, actionScore in enumerate(actionScores):
			if actionScore > bestScore:
				bestActions = [ENGINE_ACTIONS[i]]
				bestScore = actionScore
			elif actionScore == bestScore:
				bestActions.append(ENGINE_ACTIONS[i])
			logger.debug("User %s: Action %s got score %s" % (user.id, ENGINE_ACTIONS[i].ACTION_CLASS, actionScore))

		if len(bestActions) > 0 and bestScore >= 0.5:
			if (bestActions > 1):
				action = self.tieBreakActions(bestActions)
			else:
				action = bestActions[0]

			logger.debug("User %s: I think '%s' is a %s command" % (user.id, msg, action.ACTION_CLASS))

			action.execute(chunk, user)
			return True, action.ACTION_CLASS
		else:
			return self.processBasicMessages(user, msg, requestDict, keeperNumber)

	def tieBreakActions(self, actions):
		actionOrder = [StopAction, FetchWeatherAction, HelpAction, NicetyAction, SilentNicetyAction, ChangeSettingAction, QuestionAction]
		for cls in actionOrder:
			for action in actions:
				if action.__class__ == cls:
					return action

		raise NameError("Couldn't tie break")


# Process basic and important things like STOP, "hey there", "thanks", etc
# Need hacks for if those commands might be used later on though
	def processBasicMessages(self, user, msg, requestDict, keeperNumber):
		if msg_util.startsWithNo(msg):
			# If the user does "don't" or "cancel that reminder" then pause if its daytime.
			# otherwise, let it go through for now
			logger.info("User %s: I think '%s' starts with a frustration word, pausing" % (user.id, msg))
			paused = actions.unknown(user, msg, keeperNumber, sendMsg=False)
			if paused:
				return True, None

		return False, None

import logging
import collections

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

logger = logging.getLogger(__name__)

ENGINE_ACTIONS = [StopAction(), FetchWeatherAction(), QuestionAction(), NicetyAction(), SilentNicetyAction(), HelpAction(), ChangeSettingAction(), FrustrationAction(), FetchDigestAction()]


class Engine:
	def process(self, user, msg, requestDict, keeperNumber):
		# if the user
		# TODO when we implement start in the engine this check needs to move
		if user.state == keeper_constants.STATE_STOPPED:
			return False, None

		chunk = Chunk(msg)
		actionsByScore = dict()
		for action in ENGINE_ACTIONS:
			score = action.getScore(chunk, user)
			if score not in actionsByScore:
				actionsByScore[score] = list()
			actionsByScore[score].append(action)
			logger.debug("User %s: Action %s got score %s" % (user.id, action.ACTION_CLASS, score))

		sortedActionsByScore = collections.OrderedDict(sorted(actionsByScore.items(), reverse=True))

		for score, actions in sortedActionsByScore.iteritems():
			if score >= 0.5:
				if len(actions) > 1:
					actions = self.tieBreakActions(actions)

				for action in actions:
					logger.info("User %s: I think '%s' is a %s command" % (user.id, msg, action.ACTION_CLASS))
					processed = action.execute(chunk, user)

					if not processed:
						logger.info("User %s: I tried processing %s but it returned False, going onto next" % (user.id, action.ACTION_CLASS))
					else:
						return True, action.ACTION_CLASS
		return False, None

	def tieBreakActions(self, actions):
		sortedActions = list()
		actionOrder = [StopAction, FetchWeatherAction, HelpAction, NicetyAction, SilentNicetyAction, FetchDigestAction, ChangeSettingAction, QuestionAction, FrustrationAction]
		for cls in actionOrder:
			for action in actions:
				if action.__class__ == cls:
					sortedActions.append(action)
		return sortedActions

		raise NameError("Couldn't tie break")

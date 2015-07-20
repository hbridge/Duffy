import logging

from smskeeper import msg_util
from smskeeper import niceties
from smskeeper import keeper_constants
from smskeeper import actions
from smskeeper.chunk import Chunk
from smskeeper.engine.stop import StopAction

logger = logging.getLogger(__name__)

ENGINE_ACTIONS = [StopAction()]


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

		if len(bestActions) > 0 and bestScore >= 0.5:
			if (bestActions > 1):
				action = self.tieBreakActions(bestActions)
			else:
				action = bestActions[0]

			action.execute(chunk, user)
			return True, action.ACTION_CLASS
		else:
			return self.processBasicMessages(user, msg, requestDict, keeperNumber)

	def tieBreakActions(self, actions):
		actionOrder = [StopAction]
		for cls in actionOrder:
			for action in actions:
				if action.__class__ == cls:
					return action

		raise NameError("Couldn't tie break")


# Process basic and important things like STOP, "hey there", "thanks", etc
# Need hacks for if those commands might be used later on though
	def processBasicMessages(self, user, msg, requestDict, keeperNumber):
		# Always look for a stop command first and deal with that
		if niceties.getNicety(msg):
			# Hack(Derek): Make if its a nicety that also could be considered done...let that through
			if msg_util.isDoneCommand(msg):
				logger.info("User %s: I think '%s' is a nicety but its also a done command, booting out" % (user.id, msg))
				return False, None

			if msg_util.isRemindCommand(msg):
				logger.info("User %s: I think '%s' is a nicety but its also a remind command, booting out" % (user.id, msg))
				return False, None
			nicety = niceties.getNicety(msg)
			logger.info("User %s: I think '%s' is a nicety" % (user.id, msg))
			actions.nicety(user, nicety, requestDict, keeperNumber)
			classification = keeper_constants.CLASS_NICETY
			if nicety.responses is None:
				classification = keeper_constants.CLASS_SILENT_NICETY
			return True, classification
		elif msg_util.isHelpCommand(msg) and user.completed_tutorial:
			logger.info("For user %s I think '%s' is a help command" % (user.id, msg))
			actions.help(user, msg, keeperNumber)
			return True, keeper_constants.CLASS_HELP
		elif msg_util.isSetTipFrequencyCommand(msg):
			logger.info("For user %s I think '%s' is a set tip frequency command" % (user.id, msg))
			actions.setTipFrequency(user, msg, keeperNumber)
			return True, keeper_constants.CLASS_CHANGE_SETTING
		elif msg_util.nameInSetName(msg) and user.completed_tutorial:
			logger.info("User %s: I think '%s' is a set name command" % (user.id, msg))
			actions.setName(user, msg, keeperNumber)
			return True, keeper_constants.CLASS_CHANGE_SETTING
		elif msg_util.isSetZipcodeCommand(msg) and user.completed_tutorial:
			logger.info("User %s: I think '%s' is a set zip command" % (user.id, msg))
			actions.setPostalCode(user, msg, keeperNumber)
			return True, keeper_constants.CLASS_CHANGE_SETTING
		elif msg_util.isFetchWeatherCommand(msg):
			logger.info("User %s: I think '%s' is a fetch weather command" % (user.id, msg))
			actions.fetchWeather(user, msg, keeperNumber)
			return True, keeper_constants.CLASS_FETCH_WEATHER
		elif msg_util.isQuestion(msg) and user.completed_tutorial and not msg_util.isDigestCommand(msg):
			# HACKY: Doing digest check here, probably should be in a better spot
			logger.info("User %s: I think '%s' is a question, pausing" % (user.id, msg))
			actions.unknown(user, msg, keeperNumber)
			return True, None
		# If this starts to get too agressive, then move into reminder code where we see if there's
		# timing information
		elif msg_util.startsWithNo(msg):
			# If the user does "don't" or "cancel that reminder" then pause if its daytime.
			# otherwise, let it go through for now
			logger.info("User %s: I think '%s' starts with a frustration word, pausing" % (user.id, msg))
			paused = actions.unknown(user, msg, keeperNumber, sendMsg=False)
			if paused:
				return True, None

		return False, None

import json

from smskeeper import keeper_constants

from smskeeper.states import not_activated, tutorial
from smskeeper import msg_util

from smskeeper.models import User, Message

COMMAND_FUNCS = {keeper_constants.COMMAND_PICK: msg_util.isPickCommand,
				 keeper_constants.COMMAND_CLEAR: msg_util.isClearCommand,
				 keeper_constants.COMMAND_FETCH: msg_util.isFetchCommand,
				 keeper_constants.COMMAND_ADD: msg_util.isAddCommand,
				 keeper_constants.COMMAND_REMIND: msg_util.isRemindCommand,
				 keeper_constants.COMMAND_DELETE: msg_util.isDeleteCommand,
				 keeper_constants.COMMAND_ACTIVATE: msg_util.isActivateCommand,
				 keeper_constants.COMMAND_LIST: msg_util.isPrintHashtagsCommand,
				 keeper_constants.COMMAND_HELP: msg_util.isHelpCommand,
				}

def getPossibleCommands(msg):
	commandList = list()
	for key, func in COMMAND_FUNCS.iteritems():
		if func(msg):
			commandList.append(key)
	return commandList

def processMessage(user, msg, requestDict, keeperNumber):
	stateModule = stateCallbacks[user.state]
	stateModule.process(user, msg, requestDict, keeperNumber)

stateCallbacks = {
	keeper_constants.STATE_NOT_ACTIVATED : not_activated,
	keeper_constants.STATE_TUTORIAL : tutorial,
}




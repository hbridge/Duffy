import json
import logging

from smskeeper import keeper_constants

from smskeeper.states import not_activated, tutorial, remind, normal
from smskeeper import msg_util

from smskeeper.models import User, Message

logger = logging.getLogger(__name__)

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

def processMessage(phoneNumber, msg, requestDict, keeperNumber):
	try:
		user = User.objects.get(phone_number=phoneNumber)
	except User.DoesNotExist:
		try:
			user = User.objects.create(phone_number=phoneNumber)
		except Exception as e:
			logger.error("Got Exception in user creation: %s" % e)
	except Exception as e:
		logger.error("Got Exception in user creation: %s" % e)
	finally:
		Message.objects.create(user=user, msg_json=json.dumps(requestDict), incoming=True)

	processed = False
	count = 0
	while not processed and count < 10:
		stateModule = stateCallbacks[user.state]
		processed = stateModule.process(user, msg, requestDict, keeperNumber)
		count += 1

	if count == 10:
		logger.error("Hit endless loop for msg %s" % msg)

stateCallbacks = {
	keeper_constants.STATE_NOT_ACTIVATED : not_activated,
	keeper_constants.STATE_TUTORIAL : tutorial,
	keeper_constants.STATE_NORMAL : normal,
	keeper_constants.STATE_REMIND : remind,
}




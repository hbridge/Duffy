from smskeeper import msg_util
from smskeeper import keeper_constants
from smskeeper import actions

import logging
logger = logging.getLogger(__name__)


def process(user, msg, requestDict, keeperNumber):
	if "NumMedia" in requestDict:
		numMedia = int(requestDict["NumMedia"])
		if numMedia > 0:
			user.setState(keeper_constants.STATE_NORMAL)
			return False

	implicitLabel = user.getStateData(keeper_constants.IMPLICIT_LABEL_STATE_DATA_KEY)
	if not implicitLabel:
		user.setState(keeper_constants.STATE_NORMAL)
		if not keeper_constants.isTestKeeperNumber(keeperNumber):
			logger.error("Processing implicit label state without an implicit label")
		return False, None

	processed = False
	if msg_util.isClearCommand(msg):
		if msg.lower() == "clear":
			# only clear if the user just said "clear" without another label
			actions.clear(user, implicitLabel, keeperNumber)
			processed = True
		user.setState(keeper_constants.STATE_NORMAL)
	elif msg_util.isPickCommand(msg):
		label = msg_util.getLabel(msg)
		actions.pickItemFromLabel(user, implicitLabel, keeperNumber)
		processed = True
	elif msg_util.isDeleteCommand(msg):
		label, indices = msg_util.parseDeleteCommand(msg)
		actions.deleteIndicesFromLabel(user, implicitLabel, indices, keeperNumber)
		processed = True

	if not processed:
		user.setState(keeper_constants.STATE_NORMAL)

	return processed, None

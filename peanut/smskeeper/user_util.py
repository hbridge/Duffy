from smskeeper import keeper_constants

from smskeeper import sms_util


# Options for tutorial state are:
# keeper_constants.STATE_TUTORIAL_REMIND and keeper_constants.STATE_TUTORIAL_LIST
def activate(userToActivate, introPhrase, tutorialState, keeperNumber):
	if not tutorialState:
		tutorialState = keeper_constants.STATE_TUTORIAL_REMIND

	userToActivate.setActivated(True, tutorialState=tutorialState)

	msgsToSend = list()

	if introPhrase:
		msgsToSend.append(introPhrase)

	msgsToSend.extend(keeper_constants.INTRO_MESSAGES)

	sms_util.sendMsgs(userToActivate, msgsToSend, keeperNumber, delay=1)

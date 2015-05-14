from smskeeper import keeper_constants

from smskeeper import sms_util


# Options for tutorial state are:
# keeper_constants.STATE_TUTORIAL_REMIND and keeper_constants.STATE_TUTORIAL_LIST
def activate(userToActivate, magicPhrase, tutorialState, keeperNumber):
	userToActivate.setActivated(tutorialState=tutorialState)

	if magicPhrase:
		msgsToSend = ["That's the magic phrase. Welcome!"]
	else:
		msgsToSend = ["Oh hello. Someone else entered your magic phrase. Welcome!"]

	msgsToSend += keeper_constants.INTRO_MESSAGES

	sms_util.sendMsgs(userToActivate, msgsToSend, keeperNumber)

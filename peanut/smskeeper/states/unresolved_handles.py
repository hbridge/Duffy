from smskeeper import sms_util, msg_util
from smskeeper import keeper_constants
from smskeeper import actions


def resolveNextHandle(user, unresolvedHandles, keeperNumber):
	if len(unresolvedHandles) == 0:
		return

	to_resolve = unresolvedHandles[0]
	sms_util.sendMsg(user, "I can remind %s.  What's %s's phone number?" % (to_resolve, to_resolve), None, keeperNumber)
	user.setStateData("handleToResolve", to_resolve)
	user.save()


def process(user, msg, requestDict, keeperNumber):
	text, label, handles = msg_util.getMessagePieces(msg)
	phoneNumbers, remainingStr = msg_util.extractPhoneNumbers(msg)

	# If we have a handle to resolve, we're following up
	handleToResolve = user.getStateData("handleToResolve")

	if handleToResolve:
		if msg_util.isPhoneNumber(msg):  # valid input, create the handle and share the entries
			# Right now, we're assuming this came from reminders.
			# Will need to change once we have shared lists
			contact, didCreateUser, oldUser = actions.createHandle(user, handleToResolve, phoneNumbers[0], initialState=keeper_constants.STATE_NOT_ACTIVATED_FROM_REMINDER)

			"""
			Commented out by Derek. Breaking this until we re-write shared lists
			entryIds = user.getStateData(keeper_constants.ENTRY_IDS_DATA_KEY)
			if entryIds:
				entries = Entry.objects.filter(id__in=entryIds)
				actions.shareEntries(user, entries, [handleToResolve], keeperNumber)
			else:
				print "error, entryIds is None"
			"""

			# Save the handle we just resolved
			resolvedHandles = user.getStateData(keeper_constants.RESOLVED_HANDLES_DATA_KEY)
			if not resolvedHandles:
				resolvedHandles = []
			resolvedHandles.append(handleToResolve)
			user.setStateData(keeper_constants.RESOLVED_HANDLES_DATA_KEY, resolvedHandles)

			# remove the unresolved handle and see if we need to keep going
			unresolvedHandles = user.getStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY)
			unresolvedHandles.remove(handleToResolve)
			user.setStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY, unresolvedHandles)

			if len(unresolvedHandles) == 0:  # we're done resolving handles
				#  sms_util.sendMsg(user, "Great. I've shared that with %s" % (", ".join(resolvedHandles)), None, keeperNumber)
				user.setNextStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY, unresolvedHandles)
				user.setNextStateData(keeper_constants.RESOLVED_HANDLES_DATA_KEY, resolvedHandles)
				user.setState(keeper_constants.STATE_NORMAL)
				user.save()
				return False
			else:
				resolveNextHandle(user, unresolvedHandles, keeperNumber)

			user.save()
			return True
		else:  # the user responded with something other than a phone number, kick back for reprocessing
			# but mark that there's stuff still unresolved
			unresolvedHandles = user.getStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY)
			user.setNextStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY, unresolvedHandles)
			user.setState(keeper_constants.STATE_NORMAL)
			user.save()
			return False

	# We haven't started resolving yet, pick the first and start resolving
	else:
		resolveNextHandle(user, user.getStateData(keeper_constants.UNRESOLVED_HANDLES_DATA_KEY), keeperNumber)

	return True

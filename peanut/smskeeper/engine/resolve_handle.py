import logging

from smskeeper import keeper_constants
from .action import Action
from smskeeper import actions, chunk_features
from smskeeper import reminder_util
from smskeeper.models import Entry
from smskeeper import analytics

logger = logging.getLogger(__name__)


class ResolveHandleAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_RESOLVE_HANDLE

	def isInt(self, word):
		try:
			int(word)
			return True
		except ValueError:
			return False

	def getScore(self, chunk, user):
		score = 0.0

		chunkFeatures = chunk_features.ChunkFeatures(chunk, user)
		# Check for recently asked to resolve handle

		if chunkFeatures.hasPhoneNumber():
			score += 0.5
		if user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_RESOLVE_HANDLE):
			score += 0.3
		if user.getUnresolvedHandles() and len(user.getUnresolvedHandles()) > 0:
			score += 0.2

		return score

	def execute(self, chunk, user):
		# figure out which handle to resolve
		unresolvedHandles = user.getUnresolvedHandles()
		if not unresolvedHandles or len(unresolvedHandles) == 0:
			logger.error(
				"User %d: asked to execture handler resolution,"
				" but no unresolved handles", user.id
			)
			return False

		handleToResolve = unresolvedHandles[0]

		# find the phone number to set
		phoneNumbers, remainingStr = chunk.extractPhoneNumbers()
		if len(phoneNumbers) == 0:
			logger.error(
				"User %d: asked to execture handler resolution,"
				" but no phone number in chunk: %s", user.id, chunk
			)
			return False

		# create the contact
		contact, didCreateUser, oldUser = actions.createHandle(
			user,
			handleToResolve,
			phoneNumbers[0],
		)
		analytics.logUserEvent(
			user,
			"Resolved Handle",
			{
				"Did create user": didCreateUser,
			}
		)

		# share the reminder with the user
		entryIds = user.getStateData(keeper_constants.LAST_ENTRIES_IDS_KEY)
		if entryIds:
			entries = Entry.objects.filter(id__in=entryIds)
			reminder_util.shareReminders(user, entries, [handleToResolve], user.getKeeperNumber())
		else:
			logger.error("User %d: error resolving handle, entryIds is None", user.id)
			return False

		# remove the unresolved handle and see if we need to keep going
		unresolvedHandles.remove(handleToResolve)
		user.setUnresolvedHandles(unresolvedHandles)

		if len(unresolvedHandles) == 0:  # we're done resolving handles
			# TODO henry: this only works for single entry share case
			reminder_util.sendCompletionResponse(user, entries[0], False, user.getKeeperNumber())
		else:
			reminder_util.sendUnresolvedHandlesPrompt(user, user.getKeeperNumber())

		return True

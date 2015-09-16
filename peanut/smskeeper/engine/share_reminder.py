import logging

from smskeeper import keeper_constants
from .action import Action
from smskeeper import actions, chunk_features
from smskeeper import reminder_util
from smskeeper.models import Entry
from smskeeper import analytics

logger = logging.getLogger(__name__)


class ShareReminderAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_SHARE_REMINDER

	def isInt(self, word):
		try:
			int(word)
			return True
		except ValueError:
			return False

	def getScore(self, chunk, user):
		score = 0.0

		features = chunk_features.ChunkFeatures(chunk, user)
		unresolvedHandles, resolvedHandles = user.getSharePromptHandles()
		# Check for recently asked to resolve handle
		if len(resolvedHandles) > 0:
			resolvedHandlesRe = "|".join(resolvedHandles)

		if features.hasPhoneNumber():
			score += 0.5
		if chunk.matches(r'(text|.* directly|.* for me|remind|yes)'):
			score += 0.3
		if len(resolvedHandles) and chunk.contains(resolvedHandlesRe):
			score += 0.4
		if user.wasRecentlySentMsgOfClass(keeper_constants.OUTGOING_SHARE_PROMPT, num=1):
			score += 0.3

		if unresolvedHandles and len(unresolvedHandles) > 0:
			score += 0.2
		elif resolvedHandles and len(resolvedHandles) > 0:
			score += 0.2

		return score

	def execute(self, chunk, user):
		# figure out which handle to resolve
		unresolvedHandles, resolvedHandles = user.getSharePromptHandles()
		entryIds = user.getStateData(keeper_constants.LAST_ENTRIES_IDS_KEY)
		if entryIds:
			entries = Entry.objects.filter(id__in=entryIds)
		else:
			logger.error("User %d: error sharing entries, entryIds is None", user.id)
			return False

		logger.info(
			"User %d: Sharing reminders with ids:%s with unresolvedHandles:%s resolvedHandles:%s",
			user.id,
			entryIds,
			unresolvedHandles,
			resolvedHandles,
		)

		# share reminder with resolved handles first
		if resolvedHandles and len(resolvedHandles) > 0:
			reminder_util.shareReminders(user, entries, resolvedHandles, user.getKeeperNumber())
			user.setSharePromptHandles(unresolvedHandles, [])  # take resolved handles off so we don't share again

		# if there are unresolved handles, see if we got a phone number to resolve it
		if unresolvedHandles and len(unresolvedHandles) > 0:
			handleToResolve = unresolvedHandles[0]

			# find the phone number to set
			phoneNumbers, remainingStr = chunk.extractPhoneNumbers()
			if len(phoneNumbers) == 0:
				logger.error(
					"User %d: asked to resolve handle,"
					" but no phone number in chunk: %s", user.id, chunk
				)
				return False

			# create the contact
			contact, didCreateUser, oldUser = actions.createHandle(
				user,
				handleToResolve,
				phoneNumbers[0],
			)

			# since we resolved the handle, share it with the user
			reminder_util.shareReminders(user, entries, [handleToResolve], user.getKeeperNumber())
			# remove the unresolved handle and see if we need to keep going
			unresolvedHandles.remove(handleToResolve)
			resolvedHandles.append(handleToResolve)
			user.setSharePromptHandles(unresolvedHandles, [])

		if len(unresolvedHandles) == 0:  # we're done resolving handles
			# TODO henry: this only works for single entry share case
			reminder_util.sendCompletionResponse(user, entries[0], [], user.getKeeperNumber())
		else:
			logger.error("User %d: I think I'm being asked to resolve multiple handles %s in a share command", user.id, unresolvedHandles)

		return True

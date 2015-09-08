import logging
import pytz

from common import date_util

from smskeeper import reminder_util, sms_util, msg_util
from smskeeper import keeper_constants, chunk_features
from .action import Action
import collections
from smskeeper.models import Contact
from smskeeper import user_util

logger = logging.getLogger(__name__)


class CreateTodoAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_CREATE_TODO

	tutorial = False

	def __init__(self, tutorial=False):
		self.tutorial = tutorial

	def getScore(self, chunk, user):
		score = 0.0

		chunkFeatures = chunk_features.ChunkFeatures(chunk, user)

		nattyResult = chunk.getNattyResult(user)
		regexHit = msg_util.reminder_re.search(chunk.normalizedText()) is not None

		# things that match this RE will get a boost for create
		containsReminderWord = chunkFeatures.hasCreateWord()
		beginsWithReminderWord = chunkFeatures.beginsWithCreateWord()

		cleanedText = msg_util.cleanedReminder(chunk.normalizedTextWithoutTiming(user))

		if nattyResult and not regexHit:
			score = 0.5

		if not nattyResult and regexHit and len(cleanedText) > 2:
			score = 0.5

		if nattyResult and containsReminderWord:
			score = 0.6

		if self.tutorial:
			score = 0.7

		if nattyResult and regexHit:
			score = 0.9

		if score < 0.3 and chunkFeatures.beginsWithAndWord():
			score += 0.3  # for "and socks" lists of stuff

		# Get scores for recurrence and set the first frequency with a score of > 0.9
		recurScores = collections.OrderedDict(
			sorted(self.getRecurScores(chunk).items(), key=lambda t: t[1], reverse=True)
		)
		for frequency in recurScores.keys():
			if recurScores[frequency] >= 0.5:
				score = recurScores[frequency]

		if CreateTodoAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		if score < 0.9 and beginsWithReminderWord:
			score += 0.1

		return score

	def execute(self, chunk, user):
		nattyResult = chunk.getNattyResult(user)
		chunkFeatures = chunk_features.ChunkFeatures(chunk, user)
		keeperNumber = user.getKeeperNumber()

		if nattyResult is None:
			nattyResult = reminder_util.getDefaultNattyResult(chunk.originalText, user)
		elif not nattyResult.hadTime:
			nattyResult = reminder_util.fillInWithDefaultTime(user, nattyResult)

		followups = []
		if not nattyResult.validTime() or not user.isTutorialComplete():
			followups.append(keeper_constants.FOLLOWUP_TIME)

		# Get scores for recurrence and set the first frequency with a score of > 0.9
		recurScores = collections.OrderedDict(
			sorted(self.getRecurScores(chunk).items(), key=lambda t: t[1], reverse=True)
		)
		logger.info("User %s: create recurrence scores %s", user.id, recurScores)
		recurFrequency = None
		for frequency in recurScores.keys():
			if recurScores[frequency] >= 0.5:
				recurFrequency = frequency
				break

		# Figure out if there are resolved/unresolved handles
		shareHandles = None
		unresolvedHandles = None
		shareContacts = None
		if len(chunk.sharedReminderHandles()) > 0 and chunkFeatures.primaryActionIsRemind():
			shareHandles = chunk.sharedReminderHandles()
			if len(shareHandles) > 1:
				user_util.setPaused(user, True, user.getKeeperNumber(), "Multiple handles in share command")
				return True
			shareContacts, unresolvedHandles = Contact.resolveHandles(user, shareHandles)
			logger.info("User %d: handles in create_todo %d resolved %d unresolved", user.id, len(shareContacts), len(unresolvedHandles))
			if len(unresolvedHandles) > 0:
				# we have unresolved handles, set the followup
				followups.append(keeper_constants.FOLLOWUP_SHARE_UNRESOLVED)
			else:
				followups.append(keeper_constants.FOLLOWUP_SHARE_RESOLVED)
			user.setSharePromptHandles(unresolvedHandles, map(lambda contact: contact.handle, shareContacts))
		else:
			# clear out share prompt handles if there are no handles in this one
			user.setSharePromptHandles(None, None)

		entry = reminder_util.createReminderEntry(
			user,
			nattyResult,
			chunk.originalText,
			followups,
			keeperNumber,
			recurrence=recurFrequency
		)
		# We set this so it knows what entry was created
		user.setStateData(keeper_constants.LAST_ENTRIES_IDS_KEY, [entry.id])

		# if there were resolved handles, we share directly with the user
		if shareContacts and len(shareContacts) > 0:
			reminder_util.shareReminders(user, [entry], [shareContacts[0].handle], keeperNumber)

		if not user.isTutorialComplete() and not nattyResult.validTime() and entry.remind_recur == keeper_constants.RECUR_DEFAULT:
			sms_util.sendMsg(user, "Great, and when would you like to be reminded?", None, keeperNumber)
			return False
		else:
			reminder_util.sendCompletionResponse(user, entry, followups, keeperNumber)
			user.create_todo_count += 1
			user.save()

			# This is used by remind_util to see if something is a followup
			user.setStateData(keeper_constants.LAST_ACTION_KEY, date_util.unixTime(date_util.now(pytz.utc)))
		return True

	def getRecurScores(self, chunk):
		results = {}
		for frequency in keeper_constants.RECUR_REGEXES.keys():
			if chunk.contains(keeper_constants.RECUR_REGEXES[frequency]):
				if frequency == keeper_constants.RECUR_WEEKDAYS:
					# we want weekday to win out over weekly, and weekly's RE is more general
					results[frequency] = 0.9
				else:
					results[frequency] = 0.8
			else:
				results[frequency] = 0.0

		return results

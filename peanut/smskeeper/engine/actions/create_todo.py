import logging
import pytz
import random

from common import date_util

from smskeeper import reminder_util, sms_util
from smskeeper import keeper_constants, keeper_strings
from .action import Action
from smskeeper.models import Contact
from smskeeper import user_util
from smskeeper import actions

logger = logging.getLogger(__name__)


class CreateTodoAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_CREATE_TODO

	tutorial = False

	def __init__(self, tutorial=False):
		self.tutorial = tutorial

	def getScore(self, chunk, user, features):
		score = 0.0

		if features.hasTimingInfo and not features.hasReminderPhrase:
			score = 0.5

		if not features.hasTimingInfo and features.hasReminderPhrase and features.numCharactersInCleanedText > 2:
			score = 0.5

		if features.hasTimingInfo and features.hasCreateWord:
			score = 0.6

		if features.inTutorial:
			score = 0.7

		if features.hasTimingInfo and features.hasReminderPhrase:
			score = 0.9

		if score < 0.3 and features.beginsWithAndWord:
			score += 0.3  # for "and socks" lists of stuff

		# Get scores for recurrence and set the first frequency with a score of > 0.9
		recurScores = features.recurScores()
		for frequency in recurScores:
			if recurScores[frequency] >= 0.5:
				score = recurScores[frequency]

		if score < 0.3 and features.beginsWithCreateWord:
			score += 0.2  # give an extra boost if nothing else matches
		elif score < 0.9 and features.beginsWithCreateWord:
			score += 0.1  # don't make us overly certain if it's already higher match

		if features.isBroadQuestion:
			score -= 0.3

		return score

	def execute(self, chunk, user, features):
		nattyResult = chunk.getNattyResult(user)
		keeperNumber = user.getKeeperNumber()

		if nattyResult is None:
			nattyResult = reminder_util.getDefaultNattyResult(chunk.originalText, user)
		elif not nattyResult.hadTime:
			nattyResult = reminder_util.fillInWithDefaultTime(user, nattyResult)

		followups = []
		if not nattyResult.validTime() or not user.isTutorialComplete():
			followups.append(keeper_constants.FOLLOWUP_TIME)

		# Get scores for recurrence and set the first frequency with a score of > 0.9
		recurScores = features.recurScores()
		logger.info("User %s: create recurrence scores %s", user.id, recurScores)
		recurFrequency = None
		for frequency in recurScores.keys():
			if recurScores[frequency] >= 0.5:
				recurFrequency = frequency
				break

		# eval sharing
		shareContacts, shareFollowups, paused = self.evaluateSharing(chunk, user, features)
		if paused:
			return True
		followups += shareFollowups

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
			sms_util.sendMsg(user, random.choice(keeper_strings.ASK_FOR_TIME_TEXT), None, keeperNumber)
			return False
		else:
			reminder_util.sendCompletionResponse(user, entry, followups, keeperNumber)
			user.create_todo_count += 1
			user.save()

			# This is used by remind_util to see if something is a followup
			user.setStateData(keeper_constants.LAST_ACTION_KEY, date_util.unixTime(date_util.now(pytz.utc)))
		return True

	def evaluateSharing(self, chunk, user, features):
		shareHandles = None
		unresolvedHandles = None
		shareContacts = []
		followups = []

		if len(chunk.sharedReminderHandles()) > 0 and features.primaryActionIsRemind:
			shareHandles = chunk.sharedReminderHandles()
			if len(shareHandles) > 1:
				# we don't handle more than one share handle at the moment
				user_util.setPaused(user, True, user.getKeeperNumber(), "Multiple handles in share command")
				return None, None, True

			# resolve contacts so we can see what to do within the create flow
			shareContacts, unresolvedHandles = Contact.resolveHandles(user, shareHandles)
			logger.info("User %d: handles in create_todo %d resolved %d unresolved", user.id, len(shareContacts), len(unresolvedHandles))
			if len(unresolvedHandles) > 0:
				# we have unresolved handles, if there's a phone number resolve it immediately, otherwise, set a followup
				phoneNumbers, remainingStr = chunk.extractPhoneNumbers()
				if len(phoneNumbers) == 0:
					followups.append(keeper_constants.FOLLOWUP_SHARE_UNRESOLVED)
				else:
					contact, didCreateUser, oldUser = actions.createHandle(
						user,
						unresolvedHandles[0],
						phoneNumbers[0],
					)
					shareContacts = [contact]

			user.setSharePromptHandles(unresolvedHandles, map(lambda contact: contact.handle, shareContacts))
		else:
			# clear out share prompt handles if there are no handles in this one
			user.setSharePromptHandles(None, None)

		return shareContacts, followups, False

import logging
import pytz

from common import date_util

from smskeeper import reminder_util, sms_util, msg_util
from smskeeper import keeper_constants
from .action import Action


logger = logging.getLogger(__name__)


class CreateTodoAction(Action):
	ACTION_CLASS = keeper_constants.CLASS_CREATE_TODO

	lateNight = False
	tutorial = False

	def __init__(self, lateNight=False, tutorial=False):
		self.lateNight = lateNight
		self.tutorial = tutorial

	def getScore(self, chunk, user):
		score = 0.0

		nattyResult = chunk.getNattyResult(user)
		regexHit = msg_util.reminder_re.search(chunk.normalizedText()) is not None

		if nattyResult and not regexHit:
			score = 0.5

		if not nattyResult and regexHit:
			score = 0.5

		if self.tutorial:
			score = 0.7

		if self.lateNight:
			score = 0.7

		if nattyResult and regexHit:
			score = 0.9

		if CreateTodoAction.HasHistoricalMatchForChunk(chunk):
			score = 1.0

		return score

	def execute(self, chunk, user):
		nattyResult = chunk.getNattyResult(user)
		keeperNumber = user.getKeeperNumber()

		if nattyResult is None:
			nattyResult = reminder_util.getDefaultNattyResult(chunk.originalText, user)
		elif not nattyResult.hadTime:
			nattyResult = reminder_util.fillInWithDefaultTime(user, nattyResult)

		sendFollowup = False
		if not nattyResult.validTime() or not user.isTutorialComplete():
			sendFollowup = True

		entry = reminder_util.createReminderEntry(user, nattyResult, chunk.originalText, sendFollowup, keeperNumber)
		# We set this so it knows what entry was created
		user.setStateData(keeper_constants.LAST_ENTRIES_IDS_KEY, [entry.id])

		# If we're in the tutorial and they didn't give a time, then give a different follow up
		if not nattyResult.validTime() and not user.isTutorialComplete():
			sms_util.sendMsg(user, "Great, and when would you like to be reminded?", None, keeperNumber)
			return False
		else:
			reminder_util.sendCompletionResponse(user, entry, sendFollowup, keeperNumber)

			# This is used by remind_util to see if something is a followup
			user.setStateData(keeper_constants.LAST_ACTION_KEY, date_util.unixTime(date_util.now(pytz.utc)))
		return True
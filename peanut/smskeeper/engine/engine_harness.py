import pytz
import datetime
import logging

from common import date_util
from mock import patch
from smskeeper import processing_util, keeper_constants
from smskeeper.chunk import Chunk
from smskeeper.models import Entry
from smskeeper.models import User
from smskeeper.engine import Engine

logger = logging.getLogger(__name__)


class EngineSimHarness():
	@patch('common.date_util.utcnow')
	@patch('smskeeper.models.User.wasRecentlySentMsgOfClass')
	@patch('smskeeper.models.User.getActiveEntries')
	def scoreMessage(self, message, activeEntriesMock, recentMsgMock, dateMock):
		# get the user
		userId = message["user"]
		user = User(id=userId, phone_number=self.phoneNumberForUserId(message["user"]))

		# for each message setup and simulate
		self.setNow(dateMock, date_util.fromIsoString(message["added"]))
		self.setUserProps(user, message.get("userSnapshot"))

		self.setRecentOutgoingMessageClasses(message, recentMsgMock)
		self.setActiveEntries(message, activeEntriesMock)

		# actually score the message
		lines = processing_util.processSigAndSplitLines(user, message["body"])
		chunk = Chunk(lines[0])  # only process first line for now
		engine = Engine(Engine.DEFAULT, 0.0)
		processed, classification, actionScores = engine.process(user, chunk, simulate=True)

		# set the correct classification for the message object
		return classification, actionScores

	def setUserProps(self, user, userSnapshot):
		logger.info("setting props from userSnapshot: %s", userSnapshot)
		if userSnapshot:
			for key in userSnapshot.keys():
				setattr(user, key, userSnapshot.get(key))
		else:
			# default values
			user.productId = keeper_constants.TODO_PRODUCT_ID
			user.state = keeper_constants.STATE_NORMAL
			user.completed_tutorial = True
			dt = date_util.now(pytz.utc)
			user.activated = datetime.datetime(day=dt.day, year=dt.year, month=dt.month, hour=dt.hour, minute=dt.minute, second=dt.second).replace(tzinfo=pytz.utc)
			user.signature_num_lines = 0

	def setRecentOutgoingMessageClasses(self, message, mock):
		self.recentOutgoingMessageClasses = message.get("recentOutgoingMessageClasses")
		mock.side_effect = self.wasRecentlySentMsgOfClass

	# Pretends to be the real one in User
	def wasRecentlySentMsgOfClass(self, outgoingMsgClass, num=3):
		result = outgoingMsgClass in self.recentOutgoingMessageClasses[:num]
		logger.info("Was recently sent %s for user %s", outgoingMsgClass, result)
		return result

	def setActiveEntries(self, message, mock):
		self.activeEntries = message.get("activeEntriesSnapshot", [])

		newActiveEntries = []
		for entrySnapshot in self.activeEntries:
			text = entrySnapshot.get("text", "")
			remind_timestamp = date_util.fromIsoString(entrySnapshot.get("remind_timestamp"))

			entry = Entry.objects.create(creator_id=message["user"], label=keeper_constants.REMIND_LABEL, text=text, remind_timestamp=remind_timestamp)
			newActiveEntries.append(entry)

		mock.return_value = newActiveEntries

	def setNow(self, dateMock, date):
		dateMock.return_value = date

	def phoneNumberForUserId(self, uid):
		return "+1650555" + "%04d" % uid


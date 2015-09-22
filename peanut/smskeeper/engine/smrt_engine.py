import logging
import csv
import os

from smskeeper import keeper_constants
from smskeeper.engine.stop import StopAction
from smskeeper.engine.fetch_weather import FetchWeatherAction
from smskeeper.engine.question import QuestionAction
from smskeeper.engine.nicety import NicetyAction
from smskeeper.engine.silent_nicety import SilentNicetyAction
from smskeeper.engine.help import HelpAction
from smskeeper.engine.change_setting import ChangeSettingAction
from smskeeper.engine.frustration import FrustrationAction
from smskeeper.engine.fetch_digest import FetchDigestAction
from smskeeper.engine.changetime_most_recent import ChangetimeMostRecentAction
from smskeeper.engine.changetime_specific import ChangetimeSpecificAction
from smskeeper.engine.create_todo import CreateTodoAction
from smskeeper.engine.complete_todo_most_recent import CompleteTodoMostRecentAction
from smskeeper.engine.complete_todo_specific import CompleteTodoSpecificAction
from smskeeper.engine.tip_question_response import TipQuestionResponseAction
from smskeeper.engine.share_reminder import ShareReminderAction
from smskeeper.engine.jokes import JokeAction

from sklearn.externals import joblib
from smskeeper import chunk_features


logger = logging.getLogger(__name__)


class SmrtEngine:
	actionList = None
	minScore = 0.0

	DEFAULT = ([
		StopAction(),
		FetchWeatherAction(),
		QuestionAction(),
		NicetyAction(),
		SilentNicetyAction(),
		HelpAction(),
		ChangeSettingAction(),
		FrustrationAction(),
		FetchDigestAction(),
		ChangetimeMostRecentAction(),
		ChangetimeSpecificAction(),
		CreateTodoAction(),
		CompleteTodoMostRecentAction(),
		CompleteTodoSpecificAction(),
		TipQuestionResponseAction(),
		JokeAction(),
		ShareReminderAction()
	])
	TUTORIAL_BASIC = ([
		StopAction(),
		QuestionAction(),
		NicetyAction(),
		SilentNicetyAction(),
		HelpAction(),
		FrustrationAction()
	])
	TUTORIAL_STEP_2 = ([
		ChangetimeMostRecentAction(),
		ChangetimeSpecificAction(),
		CreateTodoAction(tutorial=True)
	])

	def __init__(self, actionList, minScore):
		self.actionList = actionList
		self.minScore = minScore
		parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0])

		self.model = joblib.load(parentPath + '/learning/models/model')

		with open(parentPath + '/learning/models/headers.csv', 'r') as csvfile:
			reader = csv.reader(csvfile, delimiter=',')
			done = False
			for row in reader:
				if not done:
					self.headers = row
				done = True

	def getActionFromCode(self, code):
		for entry in keeper_constants.CLASS_MENU_OPTIONS:
			if entry["code"] == code:
				classification = entry["value"]
		if classification:
			for action in self.actionList:
				if action.ACTION_CLASS == classification:
					return action
		return None

	def process(self, user, chunk, overrideClassification=None, simulate=False):
		# TODO when we implement start in the engine this check needs to move
		if user.state == keeper_constants.STATE_STOPPED:
			return False, None, {}

		features = chunk_features.ChunkFeatures(chunk, user)
		featuresDict = chunk_features.getFeaturesDict(features)

		data = list()
		for header in self.headers[:-2]:
			data.append(featuresDict[header])

		prediction = self.model.predict(data)

		predictionCode = int(prediction[0])
		action = self.getActionFromCode(predictionCode)

		if action and not simulate:
			logger.info("User %s: Starting processing of chunk: '%s'" % (user.id, chunk.originalText))
			processed = action.execute(chunk, user)

		if processed or simulate:
			return True, action.ACTION_CLASS, []

		return False, keeper_constants.CLASS_UNKNOWN, None


	def getActionScores(self, sortedActionsByScore):
		result = dict()
		for score, actions in sortedActionsByScore.iteritems():
			for action in actions:
				result[action.ACTION_CLASS] = score
		return result


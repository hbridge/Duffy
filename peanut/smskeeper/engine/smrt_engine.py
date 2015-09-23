import logging
import csv
import os
import operator

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

smrtModel = None


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

		global smrtModel

		if not smrtModel:
			logger.info("Loading model for SMRT")
			parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0])
			modelPath = parentPath + keeper_constants.LEARNING_DIR_LOC + 'model'
			logger.info("Using model path: %s " % modelPath)
			smrtModel = joblib.load(modelPath)

			headersFileLoc = parentPath + keeper_constants.LEARNING_DIR_LOC + 'headers.csv'
			logger.info("Using headers path: %s " % headersFileLoc)

			with open(headersFileLoc, 'r') as csvfile:
				logger.info("Successfully read file")
				reader = csv.reader(csvfile, delimiter=',')
				done = False
				for row in reader:
					if not done:
						self.headers = row
					done = True

			logger.info("Done loading model")

	def getActionFromCode(self, code):
		for entry in keeper_constants.CLASS_MENU_OPTIONS:
			if entry["code"] == code:
				classification = entry["value"]
		if classification:
			for action in self.actionList:
				if action.ACTION_CLASS == classification:
					return action
		return None

	def getScoresByAction(self, scores):
		result = dict()
		nparr = scores[0]

		for code in range(len(nparr)):
			action = self.getActionFromCode(code)
			if action:
				score = nparr[code]
				result[action] = float("{0:.2f}".format(score))
		return result

	def getScoresByActionName(self, scoresByAction):
		result = dict()
		for action, score in scoresByAction.iteritems():
			result[action.ACTION_CLASS] = score
		return result

	def process(self, user, chunk, overrideClassification=None, simulate=False):
		global smrtModel
		# TODO when we implement start in the engine this check needs to move
		if user.state == keeper_constants.STATE_STOPPED:
			return False, None, {}

		features = chunk_features.ChunkFeatures(chunk, user)
		featuresDict = chunk_features.getFeaturesDict(features)

		data = list()
		for header in self.headers[:-2]:
			data.append(featuresDict[header])

		scores = smrtModel.predict_proba(data)
		scoresByAction = self.getScoresByAction(scores)
		scoresByActionName = self.getScoresByActionName(scoresByAction)

		for actionName, score in sorted(scoresByActionName.items(), key=operator.itemgetter(1), reverse=True):
			logger.info("User %s: SMRT Action %s got score %s" % (user.id, actionName, score))

		processed = False

		for action, score in sorted(scoresByAction.items(), key=operator.itemgetter(1), reverse=True):
			if processed or simulate:
				break

			if score < self.minScore:
				logger.info("User %s: SMRT For msg '%s' got highest score of %s for action %s but below min of %s" % (user.id, chunk.originalText, score, action.ACTION_CLASS, self.minScore))
				return False, keeper_constants.CLASS_UNKNOWN, None

			if not simulate:
				logger.info("User %s: SMRT I think '%s' is a %s command, executing" % (user.id, chunk.originalText, action.ACTION_CLASS))
				processed = action.execute(chunk, user)

		if processed or simulate:
			return True, action.ACTION_CLASS, scoresByActionName

		return False, keeper_constants.CLASS_UNKNOWN, None

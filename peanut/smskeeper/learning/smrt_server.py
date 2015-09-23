import os
import sys
import BaseHTTPServer
import traceback
import logging
import csv
import operator
import json

from urlparse import urlparse, parse_qs

from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "../..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper import keeper_constants
from smskeeper.chunk import Chunk
from smskeeper.models import User

from sklearn.externals import joblib
from smskeeper import chunk_features


logger = logging.getLogger(__name__)

smrtModel = None


HOST_NAME = 'localhost'
PORT_NUMBER = 7995


class SmrtServerHTTPRequestHandler(BaseHTTPRequestHandler):

	def __init__(self, scoreFunc, *args):
		self.scoreFunc = scoreFunc
		BaseHTTPServer.BaseHTTPRequestHandler.__init__(self, *args)

	def do_GET(self):
		"""Respond to a GET request."""
		self.send_response(200)
		self.send_header("Content-type", "text/json")
		self.end_headers()

		response = dict()

		urldata = parse_qs(urlparse(self.path).query)

		response["result"] = True

		if "userId" in urldata:
			try:
				userId = urldata["userId"][0]
				response["userId"] = int(userId)

				msg = urldata["msg"][0]
				response["msg"] = msg

				user = User.objects.get(id=userId)
				chunk = Chunk(unicode(msg))

				scoresByAction = self.scoreFunc(user, chunk)

				response["scores"] = scoresByAction
			except Exception, e:
				response["result"] = False
				response["error"] = str(e)
				print(traceback.format_exc())

		else:
			response["result"] = False
			response["error"] = "No msgId"

		self.wfile.write(json.dumps(response))


class SmrtScorer():
	model = None
	headers = None

	def __init__(self):
		logger.info("Loading model for SMRT")
		parentPath = os.path.join(os.path.split(os.path.split(os.path.abspath(__file__))[0])[0])
		modelPath = parentPath + keeper_constants.LEARNING_DIR_LOC + 'model'
		logger.info("Using model path: %s " % modelPath)
		try:
			self.model = joblib.load(modelPath)
		except Exception, e:
			logger.info("Got exception %s loading model" % e)

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

	def score(self, user, chunk):
		logger.info("User %s: Scoring msg '%s'" % (user.id, chunk.originalText))
		features = chunk_features.ChunkFeatures(chunk, user)
		featuresDict = chunk_features.getFeaturesDict(features)

		data = list()
		for header in self.headers[:-2]:
			data.append(featuresDict[header])

		scores = self.model.predict_proba(data)
		scoresByActionName = self.getScoresByActionName(scores)

		for actionName, score in sorted(scoresByActionName.items(), key=operator.itemgetter(1), reverse=True):
			logger.info("User %s: SMRT Action %s got score %s" % (user.id, actionName, score))

		return scoresByActionName

	def getActionNameFromCode(self, code):
		for entry in keeper_constants.CLASS_MENU_OPTIONS:
			if entry["code"] == code:
				return entry["value"]
		return None

	def getScoresByActionName(self, scores):
		result = dict()
		nparr = scores[0]

		for code in range(len(nparr)):
			actionName = self.getActionNameFromCode(code)
			if actionName:
				score = nparr[code]
				result[actionName] = float("{0:.2f}".format(score))
		return result


def handleRequestsUsing(scoreFunc):
	return lambda *args: SmrtServerHTTPRequestHandler(scoreFunc, *args)


def main():
	logger.info("Server Starts - Init %s:%s" % (HOST_NAME, PORT_NUMBER))

	server_address = (HOST_NAME, PORT_NUMBER)

	smrtScorer = SmrtScorer()

	handler = handleRequestsUsing(smrtScorer.score)
	httpd = HTTPServer(server_address, handler)
	logger.info("Server Starts - Running %s:%s" % (HOST_NAME, PORT_NUMBER))
	httpd.serve_forever()

if __name__ == '__main__':
	logging.basicConfig(filename='/mnt/log/smrt-server.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	main()

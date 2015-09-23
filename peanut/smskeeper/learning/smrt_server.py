import os
import sys
import time
import BaseHTTPServer

import logging
import csv
import os
import operator
import json

from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "../..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

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


HOST_NAME = 'localhost'
PORT_NUMBER = 7995


class SmrtServerHTTPRequestHandler(BaseHTTPRequestHandler):
	def do_GET(self):
		"""Respond to a GET request."""
		self.send_response(200)
		self.send_header("Content-type", "text/json")
		self.end_headers()

		response = dict()

		response["result"] = True

		self.wfile.write(json.dumps(response))


def run():
	logger.info("Server Starts - %s:%s" % (HOST_NAME, PORT_NUMBER))

	server_address = (HOST_NAME, PORT_NUMBER)
	httpd = HTTPServer(server_address, SmrtServerHTTPRequestHandler)
	logger.info("Server Starts - %s:%s" % (HOST_NAME, PORT_NUMBER))
	httpd.serve_forever()

if __name__ == '__main__':
	logging.basicConfig(filename='/mnt/log/smrt-server.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	run()

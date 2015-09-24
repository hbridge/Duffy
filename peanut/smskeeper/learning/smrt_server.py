import os
import sys
import BaseHTTPServer
import traceback
import logging
import json

from urlparse import urlparse, parse_qs

from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "../..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from smskeeper.engine.smrt_scorer import LocalSmrtScorer


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

				featuresDictStr = urldata["featuresDict"][0]

				logger.info("User %s: For msg '%s' got features %s" % (userId, msg, featuresDictStr))
				featuresDict = json.loads(featuresDictStr)
				scoresByAction = self.scoreFunc(userId, msg, featuresDict)

				response["scores"] = scoresByAction
			except Exception, e:
				response["result"] = False
				response["error"] = str(e)
				logger.error(traceback.format_exc())

		else:
			response["result"] = False
			response["error"] = "No msgId"

		self.wfile.write(json.dumps(response))


def handleRequestsUsing(scoreFunc):
	return lambda *args: SmrtServerHTTPRequestHandler(scoreFunc, *args)


def main():
	logger.info("Server Starts - Init %s:%s" % (HOST_NAME, PORT_NUMBER))

	server_address = (HOST_NAME, PORT_NUMBER)

	smrtScorer = LocalSmrtScorer()

	handler = handleRequestsUsing(smrtScorer.score)
	httpd = HTTPServer(server_address, handler)
	logger.info("Server Starts - Running %s:%s" % (HOST_NAME, PORT_NUMBER))
	httpd.serve_forever()

if __name__ == '__main__':
	logging.basicConfig(filename='/mnt/log/smrt-server.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	main()

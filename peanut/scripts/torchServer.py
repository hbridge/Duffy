#!/usr/bin/python
# Runs a server listening to commands to either start or restart the torch server

import json
import subprocess, os, signal
import logging
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

# Running on titanblack
cmd = "torch main.lua"
mainLogfilename = "/home/duffy/torchMainLog.log"
torchLogfileName = "/home/duffy/torchLog.log"
restartLogfileName =  "/home/duffy/torchRestartLog.log"

# Running on duffy
#cmd = "./dummyScript.sh"
#mainLogfilename = "/home/derek/mainLog.log"
#torchLogfileName = "/home/derek/torchLog.log"
#restartLogfileName =  "/home/derek/torchRestartLog.log"


class torchRunner():
	def startTorch(self):
		logging.debug("in startTorch")
		response = []
		self.proc = subprocess.Popen(cmd.split(), stdout=open(torchLogfileName, 'a') )
		response.append("Started " + str(self.proc.pid))
		return response

	def stopTorch(self):
		logging.debug("in stopTorch")
		response = []
		response.append("Trying to kill...")
		if (self.proc):
			response.append("Killing process " + str(self.proc.pid))
			os.kill(self.proc.pid, signal.SIGHUP)
			os.kill(self.proc.pid, signal.SIGINT)
			os.kill(self.proc.pid, signal.SIGKILL)
		return response

	def restartTorch(self):
		logging.debug("in restartTorch")
		response = []
		response.append(self.stopTorch())
		response.append(self.startTorch())
		return response

	def getPid(self):
		return self.proc.pid

tr = torchRunner()
	
class HttpHandler(BaseHTTPRequestHandler):
	def respondSuccess(self, response):
		self.send_response(200)
		self.send_header('Content-type', 'text/html')
		self.end_headers()
		self.wfile.write(json.dumps(response))
		logging.debug("Just sent: " + json.dumps(response))
		return

	def do_GET(self):
		try:
			response = dict({'result': True})

			if self.path.startswith("/restart"):
				ret = tr.restartTorch()
				response['debug'] = ret
				self.respondSuccess(response)
				return
			elif self.path.startswith("/stop"):
				ret = tr.stopTorch()
				response['debug'] = ret
				self.respondSuccess(response)
			elif self.path.startswith("/start"):
				ret = tr.startTorch()
				response['debug'] = ret
				self.respondSuccess(response)
			elif self.path.startswith("/getpid"):
				ret = tr.getPid()
				response['debug'] = str(ret)
				self.respondSuccess(response)
			else:
				response['path'] = self.path
				self.respondSuccess(response)
				return
			return
				
		except IOError:
			logging.error('File Not Found: %s' % self.path)
			self.send_error(404,'File Not Found: %s' % self.path)

def main():
	try:
		logging.basicConfig(filename=mainLogfilename, level=logging.DEBUG)

		server = HTTPServer(('', 12345), HttpHandler)
		logging.info('started httpserver...')
		tr.startTorch()
		server.serve_forever()
	except KeyboardInterrupt:
		logging.info('^C received, shutting down server')
		tr.stopTorch()
		server.socket.close()

if __name__ == '__main__':
	main()


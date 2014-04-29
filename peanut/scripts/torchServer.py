#!/usr/bin/python
# Runs a server listening to commands to either start or restart the torch server

import json
import subprocess, os, signal
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

# Running on titanblack
cmd = "torch main.lua"
logfileName = "/home/duffy/torchLog.log"

# Running on duffy
#cmd = "./dummyScript.sh"
#logfileName = "/home/derek/torchLog.log"

class torchRunner():
	def startTorch(self):
		response = []
		self.proc = subprocess.Popen(cmd.split(), stdout=open(logfileName, 'a') )
		response.append("Started " + str(self.proc.pid))
		return response

	def stopTorch(self):
		response = []
		response.append("Trying to kill...")
		if (self.proc):
			response.append("Killing process " + str(self.proc.pid))
			self.proc.terminate()
		return response

	def restartTorch(self):
		response = []
		response.append(self.stopTorch())
		response.append(self.startTorch())
		return response

tr = torchRunner()
	
class HttpHandler(BaseHTTPRequestHandler):
	def respondSuccess(self, response):
		self.send_response(200)
		self.send_header('Content-type',	'text/html')
		self.end_headers()
		self.wfile.write(json.dumps(response))
		return

	def do_GET(self):
		try:
			response = dict({'result': True})

			if self.path.startswith("/restart"):
				ret = tr.restartTorch()
				response['restarted'] = True
				response['debug'] = ret
				self.respondSuccess(response)
				return
			else:
				response['path'] = self.path
				self.respondSuccess(response)
				return
			return
				
		except IOError:
			self.send_error(404,'File Not Found: %s' % self.path)

def main():
	try:
		server = HTTPServer(('', 12345), HttpHandler)
		print 'started httpserver...'
		tr.startTorch()
		server.serve_forever()
	except KeyboardInterrupt:
		print '^C received, shutting down server'
		tr.stopTorch()
		server.socket.close()

if __name__ == '__main__':
	main()


#!/usr/bin/python
# Runs a server listening to requests to convert a lat lon to a timezone

import json
import subprocess, os, signal
import logging
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

from tzwhere import tzwhere

logger = logging.getLogger(__name__)

timezoneFetcher = tzwhere.tzwhere()

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

			if self.path.startswith("/timezone"):
				if '?' in self.path:
					query = self.path.split('?')[1]

					responses = list()
					latlons = query.split('ll=')
					for latlon in latlons:
						latlon = latlon.replace('&', '')
						if latlon != "":
							lat, lon = latlon.split(',')
							timezoneName = timezoneFetcher.tzNameAt(float(lat), float(lon))
							responses.append(timezoneName)
						
					return self.respondSuccess(responses)
			return
				
		except IOError:
			logging.error('File Not Found: %s' % self.path)
			self.send_error(404,'File Not Found: %s' % self.path)

def main():
	logging.basicConfig(filename='/var/log/duffy/timezoner.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')

	try:
		server = HTTPServer(('', 12345), HttpHandler)
		logging.info('started timezone server...')
		server.serve_forever()
	except KeyboardInterrupt:
		logging.info('^C received, shutting down server')
		server.socket.close()

if __name__ == '__main__':
	main()


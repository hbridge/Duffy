#!/usr/bin/python
# Runs a server listening to requests to convert a lat lon to a timezone

import json
import subprocess, os, signal, sys
import logging
import datetime
from math import radians, cos, sin, asin, sqrt

from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer

from tzwhere import tzwhere

logger = logging.getLogger(__name__)

timezoneFetcher = tzwhere.tzwhere()

def haversine(lon1, lat1, lon2, lat2):
	"""
	Calculate the great circle distance between two points 
	on the earth (specified in decimal degrees)
	"""
	# convert decimal degrees to radians 
	lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
	# haversine formula 
	dlon = lon2 - lon1 
	dlat = lat2 - lat1 
	a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
	c = 2 * asin(sqrt(a)) 
	km = 6367 * c
	return km

class HttpHandler(BaseHTTPRequestHandler):
	def respondSuccess(self, response):
		self.send_response(200)
		self.send_header('Content-type', 'text/html')
		self.end_headers()
		self.wfile.write(json.dumps(response))
		logging.debug("Just sent: " + json.dumps(response))
		return

	def getCachedTimeZone(self, lat, lon, latLonCache):
		for entry in latLonCache:
			lat2, lon2, timezoneName = entry

			geoDistance = int(haversine(lon, lat, lon2, lat2))

			if geoDistance < 1000:
				return timezoneName
		return None

	def do_GET(self):
		try:
			response = dict({'result': True})
			start = datetime.datetime.now()

			if self.path.startswith("/timezone"):
				if '?' in self.path:
					query = self.path.split('?')[1]

					responses = list()
					latLonCache = list()
					latlons = query.split('ll=')
					for latlon in latlons:
						latlon = latlon.replace('&', '')
						if latlon != "":
							lat, lon = latlon.split(',')
							lat = float(lat)
							lon = float(lon)

							timezoneName = self.getCachedTimeZone(lat, lon, latLonCache)

							if not timezoneName:
								timezoneName = timezoneFetcher.tzNameAt(lat, lon)

								if timezoneName:
									latLonCache.append((lat, lon, timezoneName))
								
							responses.append(timezoneName)
						
					print "Total request time: %s" % (datetime.datetime.now() - start)
					return self.respondSuccess(responses)
			return
				
		except IOError:
			logging.error('File Not Found: %s' % self.path)
			self.send_error(404,'File Not Found: %s' % self.path)

def main():
	logging.basicConfig(filename='/var/log/duffy/timezoner.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')

	if (len(sys.argv) > 1):
		port = int(sys.argv[1])
	else:
		port = 8234
		
	try:
		server = HTTPServer(('', port), HttpHandler)
		logging.info('started timezone server...')
		server.serve_forever()
	except KeyboardInterrupt:
		logging.info('^C received, shutting down server')
		server.socket.close()

if __name__ == '__main__':
	main()


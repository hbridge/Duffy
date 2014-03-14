#!/usr/bin/python
# Server to listen on a socket and pretend to be an image server.
import socket
import json
import time
import zmq
import logging
import sys


def main(argv):
	logging.basicConfig(filename='dummyServer.log', level=logging.DEBUG)
	logging.info("Starting dummy Server")

	context = zmq.Context()
	s = context.socket(zmq.PUSH)
	r = context.socket(zmq.PULL)
	r.bind("tcp://127.0.0.1:13374")
	s.bind("tcp://127.0.0.1:13373")

	while(True):
		logging.debug("Waiting for connection...")
		cmd = r.recv_json()
		logging.debug("Got command: " + str(cmd))

		response = dict()
		response['cmd'] = cmd['cmd']

		response['images'] = dict()
		for image in cmd['images']:
			response['images'][image] = list()
			response['images'][image].append({'class_id':'n10042', 'class_name':'computer', 'confidence':'0.91'})
			response['images'][image].append({'class_id':'n10041', 'class_name':'desk', 'confidence':'0.81'})
			response['images'][image].append({'class_id':'n10041', 'class_name':'pizza', 'confidence':'0.81'})

		response['status'] = 'ok'

		time.sleep(5)

		logging.debug("Sending:  " + str(response))
		s.send_json(response)

if __name__ == "__main__":
    main(sys.argv[1:])
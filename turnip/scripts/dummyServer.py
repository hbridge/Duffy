#!/usr/bin/python
# Server to listen on a socket and pretend to be an image server.
import socket
import json
import time
import zmq

context = zmq.Context()
s = context.socket(zmq.PUSH)
r = context.socket(zmq.PULL)
r.bind("tcp://127.0.0.1:13374")
s.bind("tcp://127.0.0.1:13373")

while(True):
	cmd = r.recv_json()

	response = dict()
	response['cmd'] = cmd['cmd']

	response['images'] = dict()
	for image in cmd['images']:
		response['images'][image] = list()
		response['images'][image].append({'class_id':'n10042', 'class_name':'pizza', 'confidence':'0.91'})
		response['images'][image].append({'class_id':'n10041', 'class_name':'car', 'confidence':'0.81'})

	response['status'] = 'ok'

	print "Sending:  ", response
	s.send_json(response)
		



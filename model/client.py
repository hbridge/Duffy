import socket
import json
import time
import zmq

context = zmq.Context()
s = context.socket(zmq.PUSH)
r = context.socket(zmq.PULL)
s.connect("tcp://127.0.0.1:13374")
r.connect("tcp://127.0.0.1:13373")

cmd1 = { 'cmd':'init', 'model':'model2.mat' }
cmd2 = { 'cmd':'process', 'images': ('img1.jpg', 'img2.jpg') }

s.send_json(cmd1)
ret = r.recv_json()
print ret

s.send_json(cmd2)
ret = r.recv_json()
print ret

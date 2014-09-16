#!/usr/bin/python
import sys, os
import logging
from threading import Thread
import signal
import datetime
import pytz
import time

from twisted.internet.protocol import Factory, Protocol
from twisted.internet import reactor
 
parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)

from peanut.settings import constants
from common.models import NotificationLog

logger = logging.getLogger(__name__)

clients = dict()
stop = False

class MobileClient(Protocol):
	def connectionMade(self):
		logger.debug("a client connected")

	def connectionLost(self, reason):
		global clients
		logger.debug("a client disconnected")
		for userId, client in clients.iteritems():
			if client == self:
				del clients[userId]
				logger.info("Removing client %s" % (userId))
				break

	def dataReceived(self, data):
		global clients
		a = data.strip().split(':')

		if len(a) > 1:
			command = a[0]
			content = a[1]
 
			if command == "user_id":
				try:
					userId = int(content.strip())
					logger.info("User %s has connected" % (userId))
					clients[userId] = self
					
				except ValueError:
					logger.error("Got back bad user_id: %s " % (content))
				
			else:
				logger.debug("Got message: %s" % (a))
				
	def message(self, message):
		self.transport.write(message + '\n')

def processMessages():
	while not stop:
		now = datetime.datetime.utcnow().replace(tzinfo=pytz.utc)
		now = now.replace(microsecond=0)
		
		if now.second < 4:
			timeWithin = now - datetime.timedelta(seconds=now.second, minutes=1)
		else:
			timeWithin = now.replace(second=0)
			
		notificationLogs = NotificationLog.objects.filter(result=None).filter(msg_type=constants.NOTIFICATIONS_SOCKET_REFRESH_FEED).filter(added__gt=timeWithin)
		
		entriesToWrite = list()
		for logEntry in notificationLogs:
			userId = logEntry.user_id 
			if userId in clients:
				logger.info("Sending refresh message to %s" % (userId))
				clients[userId].message("refresh:%s" % (logEntry.id))
				logEntry.result = constants.IOS_NOTIFICATIONS_RESULT_SENT
				entriesToWrite.append(logEntry)

			if logEntry.added + datetime.timedelta(seconds=4) < now:
				logEntry.result = constants.IOS_NOTIFICATIONS_RESULT_ERROR
				entriesToWrite.append(logEntry)
				logger.info("Failed to send to %s after 4 seconds, canceling" % (userId))

		if len(entriesToWrite) > 0:
			NotificationLog.bulkUpdate(entriesToWrite, ["result"])
		
		time.sleep(.1)

def main(argv):
	if (len(sys.argv) > 1):
		port = int(sys.argv[1])
	else:
		port = 8001

	mobileClient = MobileClient
	
	factory = Factory()
	factory.protocol = mobileClient
	reactor.listenTCP(port, factory)
	logger.info("Starting... ")
	
	Thread(target = processMessages).start()

	def customHandler(signum, stackframe):
		global stop
		stop = True
		reactor.callFromThread(reactor.stop) # to stop twisted code when in the reactor loop
	signal.signal(signal.SIGINT, customHandler)
	
	reactor.run()

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/socket-server.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])


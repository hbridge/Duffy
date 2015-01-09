import datetime

from django.db import connection

requestStartTime = None
lastCheckinTime = None
lastCheckinQueryCount = 0

def startProfiling():
	global requestStartTime
	global lastCheckinTime
	global lastCheckinQueryCount
	requestStartTime = datetime.datetime.now()
	lastCheckinTime = requestStartTime
	lastCheckinQueryCount = 0

def printStats(title, printQueries = False):
	global lastCheckinTime
	global lastCheckinQueryCount

	if not lastCheckinTime:
		startProfiling()

	now = datetime.datetime.now()
	msTime = ((now-lastCheckinTime).microseconds / 1000 + (now-lastCheckinTime).seconds * 1000)
	lastCheckinTime = now

	queryCount = len(connection.queries) - lastCheckinQueryCount
	

	print "%s took %s ms and did %s queries" % (title, msTime, queryCount)

	if printQueries:
		print "QUERIES for %s" % title
		for query in connection.queries[lastCheckinQueryCount:]:
			print query

	lastCheckinQueryCount = len(connection.queries)

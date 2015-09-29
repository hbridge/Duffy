import datetime

from django.db import connection

requestStartTime = None
lastCheckinTime = None
lastCheckinQueryCount = 0
statsInited = False


def startProfiling():
	global requestStartTime
	global lastCheckinTime
	global lastCheckinQueryCount
	global statsInited
	statsInited = True
	requestStartTime = datetime.datetime.now()
	lastCheckinTime = requestStartTime
	lastCheckinQueryCount = 0


def printStats(title, printQueries=False):
	global lastCheckinTime
	global lastCheckinQueryCount
	global statsInited

	if not statsInited:
		return

	now = datetime.datetime.now()
	checkinDiff = ((now - lastCheckinTime).microseconds / 1000 + (now - lastCheckinTime).seconds * 1000)
	startDiff = ((now - requestStartTime).microseconds / 1000 + (now - requestStartTime).seconds * 1000)
	lastCheckinTime = now

	queryCount = len(connection.queries) - lastCheckinQueryCount

	print "PROFILING %s took %s ms (%s total) and did %s queries" % (title, checkinDiff, startDiff, queryCount)

	if printQueries:
		print "QUERIES for %s" % title
		for query in connection.queries[lastCheckinQueryCount:]:
			print query

	lastCheckinQueryCount = len(connection.queries)

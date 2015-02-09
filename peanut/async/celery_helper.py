import logging
import datetime

def processBatch(baseQuery, numToProcess, processBatchFunc):
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	total = 0
	processedCount = 1
	startTime = datetime.datetime.utcnow()
	nextBatch = list(set(baseQuery[:numToProcess]))
	while processedCount > 0:
		nextBatch = list(set(baseQuery[:numToProcess]))
		processedCount = processBatchFunc(nextBatch)
		total += processedCount

	endTime = datetime.datetime.utcnow()
	msTime = ((endTime-startTime).microseconds / 1000 + (endTime-startTime).seconds * 1000)
	return (total, "%s ms" % msTime)
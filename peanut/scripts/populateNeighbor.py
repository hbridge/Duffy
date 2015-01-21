#!/usr/bin/python
import sys, os, gc
import time, datetime
import logging
import math
import pytz

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django import db
from django.db.models import Q

from peanut.settings import constants
from common.models import Strand, StrandNeighbor, LocationRecord

from strand import strands_util, geo_util

logger = logging.getLogger(__name__)


def processLocationsAndStrands(recordLocations, strands):
	userBasedNeighborEntries = dict()
	idsCreated = list()
	
	for strand in strands:
		for locationRecord in recordLocations:
			if strands_util.userShouldBeNeighborToStrand(strand, locationRecord):
				distance = geo_util.getDistanceBetweenStrandAndLocationRecord(strand, locationRecord) 

				# If we've already found a record, then see if this new one has a shorter distance.
				# If so, swap in the new one
				if (strand.id, locationRecord.user_id) in idsCreated:
					strandNeighbor = userBasedNeighborEntries[(strand.id, locationRecord.user_id)]
					if strandNeighbor.distance_in_meters > distance:
						userBasedNeighborEntries[(strand.id, locationRecord.user_id)] = StrandNeighbor(strand_1_id=strand.id, strand_1_private=strand.private, strand_1_user=strand.user, strand_2_user=locationRecord.user, distance_in_meters=distance)

				elif strand.user_id != locationRecord.user_id:
					idsCreated.append((strand.id, locationRecord.user_id))
					userBasedNeighborEntries[(strand.id, locationRecord.user_id)] = StrandNeighbor(strand_1_id=strand.id, strand_1_private=strand.private, strand_1_user=strand.user, strand_2_user=locationRecord.user, distance_in_meters=distance)

	return userBasedNeighborEntries.values()

def processStrands():
	maxStrandsAtTime = 50

	strandsToProcess = Strand.objects.filter(neighbor_evaluated=False).filter(private=True).filter(product_id=2).order_by('-first_photo_time')[:maxStrandsAtTime]

	# Group strands by users, then iterate through all users one at a time, fetching the cache as we go
	strandsByUser = dict()
	for strand in strandsToProcess:
		if strand.user_id not in strandsByUser:
			strandsByUser[strand.user_id] = list()
		strandsByUser[strand.user_id].append(strand)

	for userId, nonNeighboredStrands in strandsByUser.iteritems():
		strandNeighbors = list()

		now = datetime.datetime.now().replace(tzinfo=pytz.utc)
		if nonNeighboredStrands[0].first_photo_time > (now - datetime.timedelta(days=30)):
			doNoLoc = True
		else:
			doNoLoc = False
		
		# Find all strands that are nearby
		query = Strand.objects.exclude(location_point__isnull=True).exclude(user_id=userId).filter(product_id=2)

		if doNoLoc:
			query = query.prefetch_related('photos')
			
		additional = Q()
		for strand in nonNeighboredStrands:
			timeHigh = strand.last_photo_time + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)
			timeLow = strand.first_photo_time - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)

			if strand.location_point:
				additional = Q(additional | (Q(last_photo_time__gt=timeLow) & Q(first_photo_time__lt=timeHigh) & Q(location_point__within=strand.location_point.buffer(1))))
			else:
				additional = Q(additional | (Q(last_photo_time__gt=timeLow) & Q(first_photo_time__lt=timeHigh)))

		query = query.filter(additional)

		possibleStrandNeighbors = list(query)

		logger.debug("Found %s possible strand neighbors" % len(possibleStrandNeighbors))

		strandsByStrandId = dict()
		idsCreated = list()
		for strand in nonNeighboredStrands:
			for possibleStrandNeighbor in possibleStrandNeighbors:
				if strands_util.strandsShouldBeNeighbors(strand, possibleStrandNeighbor, locationRequired = False, doNoLocation = doNoLoc):
					#usersByStrandId[possibleStrandNeighbor.id] = list(possibleStrandNeighbor.users.all())
					strandsByStrandId[strand.id] = strand
					strandsByStrandId[possibleStrandNeighbor.id] = possibleStrandNeighbor
					if possibleStrandNeighbor.id < strand.id:
						s1 = possibleStrandNeighbor
						s2 = strand
					else:
						s1 = strand
						s2 = possibleStrandNeighbor
					# This deals de-duping
					if (s1.id, s2.id) not in idsCreated:
						idsCreated.append((s1.id, s2.id))
						distance = geo_util.getDistanceBetweenStrands(s1, s2)
						strandNeighbors.append(StrandNeighbor(strand_1_id=s1.id, strand_1_private=s1.private, strand_1_user=s1.user, strand_2_id=s2.id, strand_2_private=s2.private, strand_2_user=s2.user, distance_in_meters=distance))

		
		# Now try to find all users who were around this time
		query = LocationRecord.objects.filter(accuracy__lt=constants.DISTANCE_WITHIN_METERS_FOR_ROUGH_NEIGHBORING)
		additional = Q()
		for strand in nonNeighboredStrands:
			timeHigh = strand.last_photo_time + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)
			timeLow = strand.first_photo_time - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)

			if strand.location_point:
				additional = Q(additional | (Q(timestamp__gt=timeLow) & Q(timestamp__lt=timeHigh) & Q(point__within=strand.location_point.buffer(1))))
			else:
				additional = Q(additional | (Q(timestamp__gt=timeLow) & Q(timestamp__lt=timeHigh)))

		query = query.filter(additional)

		possibleLocationRecords = list(query)

		logger.info("Found %s possible location records" % (len(possibleLocationRecords)))
	
		userStrandNeighbors = processLocationsAndStrands(possibleLocationRecords, nonNeighboredStrands)
		strandNeighbors.extend(userStrandNeighbors)

		neighborRowsToCreated, neighborRowsToUpdated = strands_util.updateOrCreateStrandNeighbors(strandNeighbors)

		for strand in nonNeighboredStrands:
			strand.neighbor_evaluated = True
		Strand.bulkUpdate(nonNeighboredStrands, ['neighbor_evaluated'])
		
		logger.info("Strand: Created %s and updated %s neighbor rows for user %s" % (len(neighborRowsToCreated), len(neighborRowsToUpdated), userId))
		
	return strandsToProcess
		

def processLocationRecords():
	maxRecordsAtTime = 50

	locationRecordsToProcess = LocationRecord.objects.filter(neighbor_evaluated=False).order_by('-timestamp')[:maxRecordsAtTime]

	# Group strands by users, then iterate through all users one at a time, fetching the cache as we go
	recordsByUser = dict()
	for record in locationRecordsToProcess:
		if record.user_id not in recordsByUser:
			recordsByUser[record.user_id] = list()
		recordsByUser[record.user_id].append(record)

	for userId, records in recordsByUser.iteritems():
		# Find all strands that are nearby
		query = Strand.objects.exclude(location_point__isnull=True).exclude(user_id=userId).filter(product_id=2)

		additional = Q()
		for record in records:
			timeHigh = record.added + datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)
			timeLow =  record.added - datetime.timedelta(minutes=constants.TIME_WITHIN_MINUTES_FOR_NEIGHBORING)

			additional = Q(additional | (Q(last_photo_time__gt=timeLow) & Q(first_photo_time__lt=timeHigh) & Q(location_point__within=record.point.buffer(1))))

		query = query.filter(additional)

		possibleStrandNeighbors = list(query)

		userStrandNeighbors = processLocationsAndStrands(records, possibleStrandNeighbors)

		neighborRowsToCreated, neighborRowsToUpdated = strands_util.updateOrCreateStrandNeighbors(userStrandNeighbors)

		for record in records:
			record.neighbor_evaluated = True
		LocationRecord.bulkUpdate(records, ['neighbor_evaluated'])
		
		logger.info("LocationRecord: Created %s and updated %s neighbor rows for user %s" % (len(neighborRowsToCreated), len(neighborRowsToUpdated), userId))
		

	return locationRecordsToProcess
	
def main(argv):
	logger.info("Starting... ")
	
	while True:
		strandsProcessed = processStrands()

		locationRecordsProcessed = processLocationRecords()
		
		db.reset_queries()
		
		if len(strandsProcessed) == 0 and len(locationRecordsProcessed) == 0:
			time.sleep(.1)

if __name__ == "__main__":
	logging.basicConfig(filename='/var/log/duffy/neighboring.log',
						level=logging.DEBUG,
						format='%(asctime)s %(levelname)s %(message)s')
	logging.getLogger('django.db.backends').setLevel(logging.ERROR) 
	main(sys.argv[1:])
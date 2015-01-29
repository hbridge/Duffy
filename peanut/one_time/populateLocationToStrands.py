import sys, os
import json
import datetime

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)
import django
django.setup()

from django.shortcuts import render
from django.http import HttpResponse
from django.db.models import Q

from async import neighboring
from peanut import settings
from common.models import Photo, User, Strand, StrandNeighbor, LocationRecord

def main(argv):
    # Fetch recent private strands that have no location_point
    strandsToProcess = Strand.objects.filter(location_point__isnull=True).filter(private=True).filter(product_id=2).order_by('-first_photo_time')[:1000]

    strandsByUserId = dict()
    for strand in strandsToProcess:
        if not strand.user_id in strandsByUserId:
            strandsByUserId[strand.user_id] = list()
        strandsByUserId[strand.user_id].append(strand)

    count = 0
    maxNum = 1
    for userId, strands in strandsByUserId.iteritems():
        strands = sorted(strands, key=lambda x: x.first_photo_time)

        timeLow = strands[0].first_photo_time - datetime.timedelta(minutes=30)
        timeHigh =  strands[-1].last_photo_time + datetime.timedelta(minutes=30)

        allLocationRecords = LocationRecord.objects.filter(Q(timestamp__gt=timeLow) & Q(timestamp__lt=timeHigh)).filter(user_id=userId)
        for strand in strands:
            timeLow = strand.first_photo_time - datetime.timedelta(minutes=30)
            timeHigh = strand.last_photo_time + datetime.timedelta(minutes=30)

            bestLocationRecord = None
            for locationRecord in allLocationRecords:
                if locationRecord.timestamp > timeLow and locationRecord.timestamp < timeHigh:
                    if not bestLocationRecord:
                        bestLocationRecord = locationRecord
                    elif locationRecord.accuracy < bestLocationRecord.accuracy:
                        bestLocationRecord = locationRecord
            if bestLocationRecord:
                print "Found location record %s with accuracy %s for strand %s" % (bestLocationRecord.id, bestLocationRecord.accuracy, strand.id)

                strand.location_point = bestLocationRecord.point
                strand.neighbor_evaluated = False
                strand.save()

                neighboring.processStrandIds.delay([strand.id])

    # Look to see if there's a location record for within 30 minutes of the strand
    # If so, apply to the strand, then run through neighboring
        

if __name__ == "__main__":
    main(sys.argv[1:])
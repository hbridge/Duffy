import sys, os
import json
import logging

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.shortcuts import render
from django.http import HttpResponse
from django.contrib.gis.geos import Point, fromstr

from photos.models import Photo, User, Classification
from peanut import settings
from photos import location_util


def chunks(l, n):
    """ Yield successive n-sized chunks from l.
    """
    for i in xrange(0, len(l), n):
        yield l[i:i+n]


def main(argv):
    maxFileAtTime = 100

    root = logging.getLogger()
    root.setLevel(logging.DEBUG)

    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    root.addHandler(ch)

    
    while True:
        # Get all photos which don't have classification data yet
        #  But also filter out test users and any photo which only has a thumb
        nonPointPhotos = Photo.objects.filter(location_point__isnull=True).filter(metadata__contains="{GPS}").exclude(user=1).exclude(thumb_filename__isnull=True).order_by('-added')

        for chunk in chunks(nonPointPhotos, maxFileAtTime):
            logging.info("Got the next %s photos that are not processed" % len(chunk))

            for photo in chunk:
                lat, lon = location_util.getLatLonFromExtraData(photo, True)

                if lat and lon:
                    photo.location_point = fromstr("POINT(%s %s)" % (lon, lat))
                    logging.debug("%s looked for lat lon and got %s" % (photo.id, photo.location_point))
                else:
                    logging.debug("Photo %s has no lat lon" % (photo.id))

            Photo.bulkUpdate(chunk, ["location_point"])
            logging.info("Updated %s photos" % len(chunk))
        else:
            logging.debug("DONE")
            return
        

if __name__ == "__main__":
    main(sys.argv[1:])
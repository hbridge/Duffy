import os, sys
import json
import urllib2
import urllib

parentPath = os.path.abspath("..")
if parentPath not in sys.path:
     sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.shortcuts import render
from django.http import HttpResponse

from photos.models import Photo, User, Classification
from peanut import settings

def getDataFromTwoFishes(lat, lon):
    queryStr = "%s,%s" % (lat, lon)
    twoFishesParams = { "ll" : queryStr }

    twoFishesUrl = "http://demo.twofishes.net/?%s" % (urllib.urlencode(twoFishesParams)) 

    twoFishesResult = urllib2.urlopen(twoFishesUrl).read()

    if (twoFishesResult):
        return twoFishesResult
    return None
        
def main(argv):
    print "Starting populate locations from two fishes"
    
    allPhotos = Photo.objects.filter(id__gte=22650)

    for photo in allPhotos:
        if photo.metadata:
            metadata = json.loads(photo.metadata)
            if "{GPS}" in metadata:
                gpsData = metadata["{GPS}"]
                if "Latitude" in gpsData:
                    lat = gpsData["Latitude"]
                    if gpsData["LatitudeRef"] == "S":
                        lat = lat * -1
                if "Longitude" in gpsData:
                    lon = gpsData["Longitude"]
                    if gpsData["LongitudeRef"] == "W":
                        lon = lon * -1

                if lat and lon:
                    print str(photo.id) + ": " + str(lat) + " " + str(lon)
                    twoFishesResult = getDataFromTwoFishes(lat, lon)
                    photo.twofishes_data = twoFishesResult
                    photo.save()

                
if __name__ == "__main__":
    main(sys.argv[1:])
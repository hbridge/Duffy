import sys
import json

if "/home/derek/Duffy/peanut" not in sys.path:
     sys.path.insert(0, "/home/derek/Duffy/peanut")

from django.shortcuts import render
from django.http import HttpResponse

from photos.models import Photo, User, Classification
from peanut import settings

def main(argv):
    maxFileCount = 10000
    maxFileAtTime = 16
    count = 0


    print "Starting populate locations"
    # Get all photos in pipeline_state 0 which means "not copied to image server"
    allPhotos = Photo.objects.all()
   

    for photo in allPhotos:
        cityJson = json.loads(photo.location_data)

        if ('address' in cityJson):
            address = cityJson['address']
            if ('City' in address):
                city = address['City']
                print city
                photo.location_city = city
                photo.save()
        

if __name__ == "__main__":
    main(sys.argv[1:])
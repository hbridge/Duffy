import sys, os
import json
import exifread

if "/home/derek/Duffy/peanut" not in sys.path:
     sys.path.insert(0, "/home/derek/Duffy/peanut")

from django.shortcuts import render
from django.http import HttpResponse

from pprint import pprint

from photos.models import Photo, User, Classification

def main(argv):
    uploadsPath = "/home/derek/pipeline/uploads"

    count = 0
    photoId = 2630
    userId = 1

    userUploadsPath = os.path.join(uploadsPath, str(userId))
    

    #for dirname, dirnames, filenames in os.walk(stagingPath):
    photo = Photo.objects.get(id = photoId)

    newFilePath = os.path.join(userUploadsPath, photo.new_filename)
        
    # Open image file for reading (binary mode)
    f = open(newFilePath, 'rb')

    # Return Exif tags
    tags = exifread.process_file(f)

    print tags["EXIF DateTimeOriginal"]
    #pprint(tags)
    
if __name__ == "__main__":
    main(sys.argv[1:])
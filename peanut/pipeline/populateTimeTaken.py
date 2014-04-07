import sys, os
import json
from datetime import datetime
import exifread

if "/home/derek/Duffy/peanut" not in sys.path:
     sys.path.insert(0, "/home/derek/Duffy/peanut")

from django.shortcuts import render
from django.http import HttpResponse

from photos.models import Photo, User, Classification
from peanut import settings


"""
    Onetime script that looks for all photos without time_taken and tries to add it.

    Shouldn't need to be run again
"""
def main(argv):
    uploadsPath = "/home/derek/pipeline/uploads"
    print "Starting populate time_taken"
    # Get all photos in pipeline_state 0 which means "not copied to image server"
    allPhotos = Photo.objects.filter(time_taken__isnull=True)
   
    for photo in allPhotos:
        foundDate = False
        print "Evaluating: " + str(photo.id)

        if (photo.metadata):
            metadata = json.loads(photo.metadata)
            for key in metadata.keys():
                if key == "{Exif}":
                    for a in metadata[key].keys():
                        if a == "DateTimeOriginal":
                            dt = datetime.strptime(metadata[key][a], "%Y:%m:%d %H:%M:%S")
                            photo.time_taken = dt
                            print(photo.time_taken)
                            photo.save()
                            foundDate = True

        if (foundDate == False):
            userUploadsPath = os.path.join(uploadsPath, str(photo.user.id))
            photoPath = os.path.join(userUploadsPath, photo.new_filename)
            
            f = open(photoPath, 'rb')
            tags = exifread.process_file(f)

            if "EXIF DateTimeOriginal" in tags:
                origTime = tags["EXIF DateTimeOriginal"]
                dt = datetime.strptime(str(origTime), "%Y:%m:%d %H:%M:%S")

                photo.time_taken = dt
                print(photo.time_taken)
                photo.save()
        

if __name__ == "__main__":
    main(sys.argv[1:])
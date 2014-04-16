import sys, os, getopt
import json
import exifread

if "/home/derek/Duffy/peanut" not in sys.path:
     sys.path.insert(0, "/home/derek/Duffy/peanut")

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from django.shortcuts import render
from django.http import HttpResponse
from peanut import settings

from photos import image_util

from pprint import pprint

from photos.models import Photo, User, Classification


"""
    Script to manually injest files that were uploaded to the server, probably by FTP

    This creates a newly resized image to the size like the iPhone sends over, then calls
    the image_util code to add it
"""
def main(argv):
    size = 513

    try:
        opts, args = getopt.getopt(argv,"hu:d:",["userId="])
    except getopt.GetoptError:
        print 'injestFiles.py -u <userId> -d <uploadedFilesDirectory>'
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print 'injestFiles.py -u <userId> -d <uploadedFilesDirectory>'
            sys.exit()
        elif opt in '-u':
            userId = int(arg)
        elif opt in '-d':
            uploadsPath = arg

    userDataPath = os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, str(userId))

    try:
        user = User.objects.get(id=userId)
    except User.DoesNotExist:
        print("Could not find user by id: %d" % userId)
        exit()



    for dirname, dirnames, filenames in os.walk(uploadsPath):
        print("Looking in dir: %s" % dirname)

        for filename in filenames:
            
            newFilename = os.path.splitext(os.path.basename(filename))[0] + "-thumb-" + str(size) + '.jpg'
            newFilepath = os.path.join(dirname, newFilename)
            origFilepath = os.path.join(dirname, filename)
            
            print("Processing: %s" % origFilepath)

            image_util.resizeImage(origFilepath, newFilepath, size, False)

            image_util.addPhoto(user, filename, newFilepath, "", "", "")

            os.remove(origFilepath)


if __name__ == "__main__":
    main(sys.argv[1:])
import sys, getopt, os
import subprocess
import logging
import time
import json
import socket
import time
import zmq

if "/home/derek/Duffy/peanut" not in sys.path:
     sys.path.insert(0, "/home/derek/Duffy/peanut")

from django.shortcuts import render
from django.http import HttpResponse

# Create your views here.
from photos.models import Photo, User, Classification
from peanut import settings

def main(argv):
    maxFileCount = 10000
    maxFileAtTime = 16
    count = 0


    print "Starting pipeline"
    # Get all photos in pipeline_state 0 which means "not copied to image server"
    nonClassifiedPhotos = Photo.objects.all()
   
    for photo in nonClassifiedPhotos:
        output = list()
        print photo.new_filename
        classifications = Classification.objects.filter(photo_id = photo.id)
        for classification in classifications:
            classInfo = dict()
            classInfo["class_name"] = classification.class_name
            classInfo["rating"] = classification.rating
            output.append(classInfo)
        photo.classification_data = json.dumps(output)
        photo.save()

if __name__ == "__main__":
    main(sys.argv[1:])
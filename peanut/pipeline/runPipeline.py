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

def initClassifier():
    context = zmq.Context()
    socket_send = context.socket(zmq.PUSH)
    socket_recv = context.socket(zmq.PULL)
    socket_send.connect("tcp://titanblack.no-ip.biz:14921")
    socket_recv.connect("tcp://titanblack.no-ip.biz:14920")

    return (socket_send, socket_recv)

def classifyPhotos(photos, socket_send, socket_recv):
    successfullyClassified = list()
    cmd = dict()
    cmd['cmd'] = 'process'
    cmd['images'] = list()

    pathToPhoto = dict()

    print("About to process files:")
    for photo in photos:
        imagepath = os.path.join(settings.PIPELINE_REMOTE_PATH, str(photo.user.id), photo.new_filename)
        pathToPhoto[imagepath] = photo

        cmd['images'].append(imagepath)

    print("Sending:  " + str(cmd))
    socket_send.send_json(cmd)
    
    print("Waiting for response...")
    result = socket_recv.recv_json()
    print("Got back: " + str(result))

    for imagepath in result['images']:
        photo = pathToPhoto[imagepath]

        if result['images'][imagepath] is not "not_found":
            Classification.objects.filter(user_id = photo.user.id, photo_id = photo.id).delete()

            for classinfo in result['images'][imagepath]:
                classification = Classification(class_name = classinfo['name'], rating = classinfo['confidence'])
                classification.user_id = photo.user.id
                classification.photo_id = photo.id
                classification.save()

            photo.pipeline_state = settings.STATE_CLASSIFIED
            photo.save()

            successfullyClassified.append(photo)
        else:
            print("*** File not found: " + imagepath)
    return successfullyClassified
    
def copyPhotos(photos):
    successfullyCopied = list()
    for photo in photos:
        userId = str(photo.user.id)
        # Setup user's staging dir on duffy
        userRemoteStagingPath = os.path.join(settings.PIPELINE_REMOTE_PATH, userId) + "/"
        userDataPath = os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, userId)
        imagepath = os.path.join(settings.PIPELINE_UPLOADED_PATH, userId, photo.new_filename)

        print("Sending to image server:  " + imagepath + " to " + userRemoteStagingPath)
        subprocess.call(['scp', imagepath, settings.PIPELINE_REMOTE_HOST + ":" + userRemoteStagingPath])
        subprocess.call(['cp', '-f', imagepath, userDataPath])

        try:
            photo = Photo.objects.get(id=photo.id)
            photo.pipeline_state = settings.STATE_COPIED
            photo.save()

            successfullyCopied.append(photo)
        except Photo.DoesNotExist:
            print("Photo: " + photo.id + " doesn't seem to exist anymore")
    return successfullyCopied

def chunks(l, n):
    """ Yield successive n-sized chunks from l.
    """
    for i in xrange(0, len(l), n):
        yield l[i:i+n]

def main(argv):
    maxFileCount = 10000
    maxFileAtTime = 16
    count = 0

    socket_send, socket_recv = initClassifier()

    print "Starting pipeline"
    # Get all photos in pipeline_state 0 which means "not copied to image server"
    nonUploadedPhotos = Photo.objects.filter(pipeline_state=settings.STATE_NEW)
    nonUploadedPhotos = nonUploadedPhotos[:maxFileCount]

    successfullyClassified = list()
    
    for photos in chunks(nonUploadedPhotos, maxFileAtTime):
        # TODO(Derek):  This is inefficient, we could parallalize uploads and classification but simplifying to start
        successfullyCopied = copyPhotos(photos)
        successfullyClassified = classifyPhotos(successfullyCopied, socket_send, socket_recv)
        count += len (successfullyClassified)

    print "Pipeline complete. " + str(count) + " photos processed"

if __name__ == "__main__":
    main(sys.argv[1:])
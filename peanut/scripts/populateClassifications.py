#!/usr/bin/python
import sys, getopt, os
import subprocess
import logging
import time
import json
import socket
import time
import zmq
import Image
import datetime


parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

from peanut import settings
from common.models import Photo, User, Classification

def initClassifier():
    attempts = 0

    while attempts < 1000:
        try:
            context = zmq.Context()
            socket_send = context.socket(zmq.PUSH)
            socket_recv = context.socket(zmq.PULL)
            socket_send.connect("tcp://titanblack.no-ip.biz:14921")
            socket_recv.connect("tcp://titanblack.no-ip.biz:14920")

            return (context, socket_send, socket_recv)
        except zmq.error.ZMQError:
            logging.error("Got connection error to titanblack.  sleeping for 10 seconds then trying again")
            time.sleep(10)
            attempts += 1
    logging.error("Tried to connect and failed")

def getIdFromImagePath(imagePath):
    base, origFilename = os.path.split(imagePath)
    photoId, ext = os.path.splitext(origFilename)

    try:
        return int(photoId)
    except ValueError:
        return None

def getPhotoFromList(photoId, photos):
    if photoId:
        for photo in photos:
            if photo.id == photoId:
                return photo
    return None

def processResponse(response):
    photoIds = list()
    photosToSave = list()

    # We might get back responses for different images
    for imagepath in response['images']:
        photoId = getIdFromImagePath(imagepath)
        if photoId:
            photoIds.append(photoId)

    photos = Photo.objects.filter(id__in=photoIds)

    for imagepath in response['images']:
        photoId = getIdFromImagePath(imagepath)

        photo = getPhotoFromList(photoId, photos)

        if response['images'][imagepath] is not "not_found" and photo:
            Classification.objects.filter(user_id = photo.user.id, photo_id = photo.id).delete()

            classificationDataInPhoto = list()
            for classInfo in response['images'][imagepath]:
                classification = Classification(class_name = classInfo['name'], rating = classInfo['confidence'])
                classification.user_id = photo.user.id
                classification.photo_id = photo.id
                classification.save()

                # We're making a copy of the data to switch names from name to class_name and confidence to rating
                infoCopy = dict()
                infoCopy["class_name"] = classInfo['name']
                infoCopy["rating"] = classInfo['confidence']
                classificationDataInPhoto.append(infoCopy)

            photo.classification_data = json.dumps(classificationDataInPhoto)
            photosToSave.append(photo)
        else:
            logging.info("*** Photo not found: " + imagepath)

    if (len(photosToSave) > 0):
        Photo.bulkUpdate(photosToSave, ["classification_data"])

    return photosToSave

def recvPhotos(socket_recv, timeToWaitSec=60, keepGoing=False):
    processedPhotos = list()
    timeStart = datetime.datetime.now()
    timeDelta = datetime.timedelta(seconds=timeToWaitSec) 
    timeEnd = timeStart + timeDelta
    
    logging.info("Waiting %s seconds for response..." % (timeToWaitSec))
    while datetime.datetime.now() < timeEnd:
        result = socket_recv.poll(500)
        if result > 0:
            result = socket_recv.recv_json()
            logging.info("Got back: " + str(result))

            savedPhotos = processResponse(result)
            processedPhotos.extend(savedPhotos)

            if keepGoing:
                timeEnd = datetime.datetime.now() + timeDelta
            else:
                return processedPhotos
        
    return processedPhotos

def sendPhotos(photos, socket_send):
    cmd = dict()
    cmd['cmd'] = 'process'
    cmd['images'] = list()

    logging.info("About to process files (at " + time.strftime("%c") + "):")
    for photo in photos:
        imagepath = os.path.join(settings.PIPELINE_REMOTE_PATH, photo.full_filename)
        cmd['images'].append(imagepath)

    gotResponse = False
    
    logging.info("Sending:  " + str(cmd))
    socket_send.send_json(cmd)
    
def copyPhotos(photos):
    successfullyCopied = list()
    for photo in photos:
        userId = str(photo.user.id)
        # Setup user's staging dir on duffy
        userDataPath = os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, userId)
        imagepath = os.path.join(userDataPath, photo.full_filename)

        # Check that there are three channels
        im = Image.open(imagepath)
        if (im.getbands() != ('R', 'G', 'B')):
            logging.warning("Found image with wrong channels:  " + imagepath)            
            photo.classification_data = json.dumps([{"class_name": "wrong_channels", "rating": 1.0}])
            photo.save()
        else:
            logging.info("Sending to image server:  " + imagepath + " to " + settings.PIPELINE_REMOTE_PATH)
            ret = subprocess.call(['scp', imagepath, settings.PIPELINE_REMOTE_HOST + ":" + settings.PIPELINE_REMOTE_PATH])
            
            if ret == 0:
                successfullyCopied.append(photo)

    return successfullyCopied

def chunks(l, n):
    """ Yield successive n-sized chunks from l.
    """
    for i in xrange(0, len(l), n):
        yield l[i:i+n]

def main(argv):
    maxFileCount = 10000
    maxFileAtTime = 16

    logging.basicConfig(filename='/var/log/duffy/classifier.log',
                        level=logging.DEBUG,
                        format='%(asctime)s %(levelname)s %(message)s')
    logging.getLogger('django.db.backends').setLevel(logging.ERROR) 

    context, socket_send, socket_recv = initClassifier()
    

    logging.info("Starting pipeline at " + time.strftime("%c"))

    logging.info("Seeing if there's any pending photos to process...")
    successfullyClassified = recvPhotos(socket_recv, timeToWaitSec=5, keepGoing=True)
    logging.info("Found pending photos and successfully completed " + str(len(successfullyClassified)) + " photos")

    while True:
        successfullyClassified = list()
        # Get all photos which don't have classification data yet
        #  But also filter out test users and any photo which only has a thumb
        nonProcessedPhotos = Photo.objects.filter(classification_data__isnull=True).exclude(user=1).exclude(full_filename__isnull=True).filter(user__product_id=0).order_by('-added')[:maxFileAtTime]

        if len(nonProcessedPhotos) > 0:
            logging.info("Got the next " + str(len(nonProcessedPhotos)) + " photos that are not processed")
            # TODO(Derek):  This is inefficient, we could parallalize uploads and classification but simplifying to start
            successfullyCopied = copyPhotos(nonProcessedPhotos)
            if (len(successfullyCopied) > 0):
                sendPhotos(successfullyCopied, socket_send)
                successfullyClassified = recvPhotos(socket_recv)

            if len(successfullyClassified) > 0:
                logging.info("Successfully completed " + str(len(successfullyClassified)) + " photos")
            else:
                logging.error("Did not hear back, server probably died, reconnecting sockets")
                
                context.destroy()
                context, socket_send, socket_recv = initClassifier()
                
                successfullyClassified = recvPhotos(socket_recv, timeToWaitSec=60, keepGoing=True)

                if len(successfullyClassified) > 0:
                    logging.info("Recovered and successfully completed " + str(len(successfullyClassified)) + " photos")
                else:
                    logging.error("Did not complete classification...sleeping for 5 minutes then will try to reconnect and resend")
                    time.sleep(60*5)
                    
                    logging.error("Back from sleep, trying to reconnect")
                    context.destroy()
                    context, socket_send, socket_recv = initClassifier()
                    logging.info("Got back from init:  %s %s %s" % context, socket_send, socket_recv)
        else:
            time.sleep(5)


if __name__ == "__main__":
    main(sys.argv[1:])

import sys, getopt, os
import subprocess
import logging
import time
import json
import socket
import time
import zmq

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "peanut.settings")

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

    logging.info("About to process files (at " + time.strftime("%c") + "):")
    for photo in photos:
        imagepath = os.path.join(settings.PIPELINE_REMOTE_PATH, photo.full_filename)
        pathToPhoto[imagepath] = photo

        cmd['images'].append(imagepath)

    logging.info("Sending:  " + str(cmd))
    socket_send.send_json(cmd)
    
    logging.info("Waiting for response...")
    result = socket_recv.recv_json()
    logging.info("Got back: " + str(result))


    # We might get back responses for different images
    for imagepath in result['images']:
        if imagepath in pathToPhoto:
            photo = pathToPhoto[imagepath]
        else:
            logging.info("*** Unkonwn file - looking up in db: " + imagepath)
            # need to do a lookup
            base, origFilename = os.path.split(imagepath)
            filenameNoExt, extension = os.path.splitext(origFilename)
            photoId = filenameNoExt.split('-')[0]

            photo = Photo.objects.filter(id=photoId)

        if result['images'][imagepath] is not "not_found":
            Classification.objects.filter(user_id = photo.user.id, photo_id = photo.id).delete()

            classificationDataInPhoto = list()
            for classInfo in result['images'][imagepath]:
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
            photo.save()

            successfullyClassified.append(photo)
        else:
            logging.info("*** File not found: " + imagepath)
    return successfullyClassified
    
def copyPhotos(photos):
    successfullyCopied = list()
    for photo in photos:
        userId = str(photo.user.id)
        # Setup user's staging dir on duffy
        userDataPath = os.path.join(settings.PIPELINE_LOCAL_BASE_PATH, userId)
        imagepath = os.path.join(userDataPath, photo.full_filename)

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

    socket_send, socket_recv = initClassifier()

    while True:
        count = 0
        logging.info("Starting pipeline at " + time.strftime("%c"))
        # Get all photos which don't have classification data yet
        #  But also filter out test users and any photo which only has a thumb
        nonProcessedPhotos = Photo.objects.filter(classification_data__isnull=True).exclude(user=1).exclude(full_filename__isnull=True)
        nonProcessedPhotos = nonProcessedPhotos[:maxFileCount]

        successfullyClassified = list()

        logging.info("Found " + str(len(nonProcessedPhotos)) + " photos that are not processed")
        
        for photos in chunks(nonProcessedPhotos, maxFileAtTime):
            # TODO(Derek):  This is inefficient, we could parallalize uploads and classification but simplifying to start
            successfullyCopied = copyPhotos(photos)
            if (len(successfullyCopied) > 0):
                successfullyClassified = classifyPhotos(successfullyCopied, socket_send, socket_recv)
                count += len (successfullyClassified)

        logging.info("Pipeline complete. " + str(count) + " photos processed")

        time.sleep(5)

if __name__ == "__main__":
    main(sys.argv[1:])

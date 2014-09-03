#!/usr/bin/python
import sys, getopt, os
import logging
import time
import json
import time
from PIL import Image

import overfeat
import numpy
from scipy.ndimage import imread
from scipy.misc import imresize

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)

from common.models import Photo

def runOverfeat(photo):
    image = imread(photo.getFullPath())

    # resize and crop into a 231x231 image
    h0 = image.shape[0]
    w0 = image.shape[1]
    d0 = float(min(h0, w0))

    try:
        image = image[int(round((h0-d0)/2.)):int(round((h0-d0)/2.)+d0),
                  int(round((w0-d0)/2.)):int(round((w0-d0)/2.)+d0), :]
    except IndexError:
        # Deal with exception:
        # File "/home/derek/prod/Duffy/peanut/scripts/populateOverfeat.py", line 31, in runOverfeat
        #   int(round((w0-d0)/2.)):int(round((w0-d0)/2.)+d0), :]
        return []
        
    image = imresize(image, (231, 231)).astype(numpy.float32)

    # numpy loads image with colors as last dimension, transpose tensor
    h = image.shape[0]
    w = image.shape[1]
    c = image.shape[2]
    image = image.reshape(w*h, c)
    image = image.transpose()
    image = image.reshape(c, h, w)
   
    # run overfeat on the image
    b = overfeat.fprop(image)

    b = b.flatten()
    top = [(b[i], i) for i in xrange(len(b))]
    top.sort()

    overfeatData = list()
    for i in xrange(5):
        className = overfeat.get_class_name(top[-(i+1)][1])
        rating = top[-(i+1)][0]

        overfeatData.append({'class_name': className, 'rating': str(rating)})

    return overfeatData


def processPhotos(photos):
    for photo in photos:
        overfeatData = runOverfeat(photo)
        photo.overfeat_data = json.dumps(overfeatData)
        logging.debug("For photo %s/%s got %s " % (photo.user_id, photo.id, photo.overfeat_data))


    logging.debug("Updating %s photos in database" % len(photos))
    Photo.bulkUpdate(photos, ["overfeat_data"])

    return photos

def main(argv):
    maxFileAtTime = 4

    logging.basicConfig(filename='/var/log/duffy/overfeat.log',
                        level=logging.DEBUG,
                        format='%(asctime)s %(levelname)s %(message)s')
    logging.getLogger('django.db.backends').setLevel(logging.ERROR) 

    logging.info("Starting Overfeat pipeline at " + time.strftime("%c"))
    
     # initialize overfeat. Note that this takes time, so do it only once if possible
    overfeat.init('/home/derek/overfeat/data/default/net_weight_1', 1)

    logging.info("Running with net of size: %s" % str(overfeat.get_n_layers()))


    while True:
        # Get all photos which don't have classification data yet
        #  But also filter out test users and any photo which only has a thumb
        nonProcessedPhotos = list(Photo.objects.filter(overfeat_data__isnull=True).exclude(user=1).exclude(full_filename__isnull=True).filter(user__product_id=0).order_by('-added')[:maxFileAtTime])

        if len(nonProcessedPhotos) > 0:
            logging.info("Got the next " + str(len(nonProcessedPhotos)) + " photos that are not processed")

            resultPhotos = processPhotos(nonProcessedPhotos)
        else:
            time.sleep(1)


if __name__ == "__main__":
    main(sys.argv[1:])

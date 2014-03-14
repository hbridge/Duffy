#!/usr/bin/python
# Runs on Duffy
# Copies files from "staging" to "processing" in batches of 128 then runs the model

import sys, getopt, os
from subprocess import call

import socket
import json
import time
import zmq
import csv
import random
import string
import logging

#
# Method to take in a list of images already in the "processing" dir and run them through
#   the classifier.  Then move images to "processed" and send output file to server and send index command
#
def processImages(imageFileList, processedPath, outputPath):
    context = zmq.Context()
    socket_send = context.socket(zmq.PUSH)
    socket_recv = context.socket(zmq.PULL)
    socket_send.connect("tcp://127.0.0.1:13374")
    socket_recv.connect("tcp://127.0.0.1:13373")

    #  SEND TO CLASSIFIER
    cmd = dict()
    cmd['cmd'] = 'process'
    cmd['images'] = list()

    logging.debug("About to process files:")
    for imagepath in imageFileList:
        logging.debug(imagepath)
        cmd['images'].append(imagepath)

    logging.debug("Sending:  " + str(cmd))
    socket_send.send_json(cmd)
    
    logging.debug("Waiting for response...")
    ret = socket_recv.recv_json()
    logging.debug("Got back: " + str(ret))

    outputFileNames = list()
    rndFileName = ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(6)) + ".csv"

    outputFileLoc = os.path.join(outputPath, rndFileName)
    with open(str(outputFileLoc), 'w') as csvfile:
        writer = csv.writer(csvfile)

        for imagepath in ret['images']:
            base, filename = os.path.split(imagepath)
            base, userId = os.path.split(base)

            output = list()
            output.append(userId)
            output.append(filename)
            for classinfo in ret['images'][imagepath]:
                classStr = classinfo['class_name'] + " (" + classinfo['confidence'] + ")"
                output.append(classStr)

            writer.writerow(output)

            userProcessedPath = os.path.join(processedPath, userId)
            try:
                os.stat(userProcessedPath)
            except:
                os.mkdir(userProcessedPath)
            call (['mv', imagepath, os.path.join(userProcessedPath, filename)])
    return outputFileLoc

def getNextImagesToProcess(stagingPath, processingPath, maxCount):
    imageCount = 0
    imagesToProcess = list()

    for dirname, dirnames, filenames in os.walk(stagingPath):
        # Each subdir is a userId
        for userId in dirnames:
            userStagingPath = os.path.join(stagingPath, userId)
            
            # Setup user's processing path
            userProcessingPath = os.path.join(processingPath, userId)
            try:
                os.stat(userProcessingPath)
            except:
                os.mkdir(userProcessingPath)

            # Send all pending images to server then mv to processingdir
            for dirname, dirnames, filenames in os.walk(userStagingPath):
                for filename in filenames:
                    imagepath = os.path.join(userStagingPath, filename)

                    if imageCount < maxCount:
                        call (['mv', imagepath, userProcessingPath])
                        movedImagePath = os.path.join(userProcessingPath, filename)

                    
                        imagesToProcess.append(movedImagePath)
                        imageCount += 1
                    else:
                        return imagesToProcess
    return imagesToProcess

def exportOutput(outputFileLoc, webHost, remoteOutputPath):
    # SEND TO WEB SERVER
    logging.debug("Copying " + outputFileLoc + " " + webHost + ":" + remoteOutputPath)
    call (['ssh', webHost, "mkdir -p " + remoteOutputPath])
    call (['scp', outputFileLoc, webHost + ":" + remoteOutputPath])

    base, filename = os.path.split(outputFileLoc)
    call (['ssh', webHost, "/home2/derektes/public_html/photos/turnip/scripts/step4.py -i " + filename])


def main(argv):
    basePath = '/home/derek/pipeline'
    stagingDir = 'staging'
    processingDir = 'processing'
    processedDir = 'processed'
    outputDir = 'output'
    webHost = 'derektes@derektest1.com'
    remoteBasePath = '/home2/derektes/public_html/photos/turnip/pipeline'
    imageCountMax = 2

    logging.basicConfig(filename=os.path.join(os.path.dirname(os.path.realpath(__file__)),'step3.log'), level=logging.DEBUG)
    logging.debug("Starting Step3")
    
    try:
        opts, args = getopt.getopt(argv,"hb:w:r:",["bpath=","whost=","rpath="])
    except getopt.GetoptError:
        print 'step3.py -b <base path> -w <webhost> -r <remote base path>'
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print 'step3.py  -b <base path> -w <webhost> -r <remote base path>'
            sys.exit()
        elif opt in ("-b", "--bpath"):
            basePath = arg
        elif opt in ("-w", "--whost"):
            webHost = arg
        elif opt in ("-r", "--rpath"):
            remoteBasePath = arg

    stagingPath = os.path.join(basePath, stagingDir)
    processingPath = os.path.join(basePath, processingDir)
    processedPath = os.path.join(basePath, processedDir)
    outputPath = os.path.join(basePath, outputDir)
    remoteOutputPath = os.path.join(remoteBasePath, outputDir)

    imagesToProcess = getNextImagesToProcess(stagingPath, processingPath, imageCountMax)

    if (len(imagesToProcess) == 0):
        logging.info("No images to process")

    while (len(imagesToProcess) > 0):
        outputFileLoc = processImages(imagesToProcess, processedPath, outputPath)
        exportOutput(outputFileLoc, webHost, remoteOutputPath)

        imagesToProcess = getNextImagesToProcess(stagingPath, processingPath, imageCountMax)

    logging.debug("Stopping Step3")

if __name__ == "__main__":
    main(sys.argv[1:])
    

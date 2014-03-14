#!/usr/bin/python
# Runs on Duffy
# Copies files from "staging" to "processing" in batches of 128 then runs the model

import sys, getopt, os
import csv
from subprocess import call


def main(argv):
    basePath = '/home2/derektes/public_html/photos/turnip/pipeline'
    stagingDir = 'staging'
    processingDir = 'processing'
    processedDir = 'processed'
    outputDir = 'output'
    dataBase = '/home2/derektes/public_html/photos/turnip/user_data'

    inputFileName = ''

    processingPath = os.path.join(basePath, processingDir)

    try:
        opts, args = getopt.getopt(argv,"hb:i:",["bpath=", "ifile="])
    except getopt.GetoptError:
        print 'step3.py -b <base path> -i <input file> '
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print 'step3.py  -s <staging dir> -p <processing dir> -w <webhost>'
            sys.exit()
        elif opt in ("-b", "--bpath"):
            basePath = arg
        elif opt in ("-i", "--ifile"):
            inputFileName = arg


    userEntries = dict()

    inputFileLoc = os.path.join(basePath, outputDir, inputFileName)
    with open(inputFileLoc, 'r') as csvfile:
        reader = csv.reader(csvfile)
        for row in reader:
            userId = row[0]

            if userId not in userEntries:
                userEntries[userId] = list()

            userEntries[userId].append(row[1:])

    for userId, entries in userEntries.iteritems():
        userDataPath = os.path.join(dataBase, userId)

        try:
            os.stat(userDataPath)
        except:
            os.mkdir(userDataPath)

        indexFile = os.path.join(userDataPath, "index.csv")

        # See if image already has an entry
        with open(indexFile, 'a') as csvfile:
            writer = csv.writer(csvfile)

            for entry in entries:
                imageFile = os.path.join(processingPath, userId, entry[0])
                userPhotosPath = os.path.join(dataBase, userId, "photos")

                try:
                    os.stat(userPhotosPath)
                except:
                    os.mkdir(userPhotosPath)
                
                call (['mv', imageFile, userPhotosPath])
                writer.writerow(entry)


if __name__ == "__main__":
    main(sys.argv[1:])
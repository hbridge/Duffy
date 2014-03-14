#!/usr/bin/python
# Copies files from the "uploaded" directory to duffy/staging then moves local files to "processing"

import sys, getopt, os
from subprocess import call
import logging

from socket import *
import threading
import thread

def startStep3(remoteHost, step3Script):
	logging.info("Sending command to start Step 3")
	call (['ssh', remoteHost, step3Script, "&"])

def getUserIds(uploadedPath):
	userIds = list()

	for dirname, dirnames, filenames in os.walk(uploadedPath):
		# Each subdir is a userId
		for userId in dirnames:

			# Do Not Process directory
			if (not userId.startswith("dnp")):
				userUploadedPath = os.path.join(uploadedPath, userId)
				fileCount = len([name for name in os.listdir(userUploadedPath) if os.path.isfile(os.path.join(userUploadedPath,name))])

				if (fileCount > 0):
					logging.debug("Found userId " + userId + " with " + str(fileCount) + " files for processing, adding")
					userIds.append(userId)

	return userIds


def startStep2(userIds, maxFileCount, countBeforeStartStep3, step3Script, uploadedPath, processingPath, stagingDir, remoteHost, remoteBasePath):
	step3Started = False
	fileCount = 0

	for userId in userIds:
		userUploadedPath = os.path.join(uploadedPath, userId)

		# Setup user's processing dir
		userProcessingPath = os.path.join(processingPath, userId)
		try:
			os.stat(userProcessingPath)
		except:
			os.mkdir(userProcessingPath)

		# Setup user's staging dir on duffy
		userRemoteStagingPath = os.path.join(remoteBasePath, stagingDir, userId)
		call (['ssh', remoteHost, "mkdir -p " + userRemoteStagingPath])

		# Send all pending images to server then mv to processingdir
		for dirname, dirnames, filenames in os.walk(userUploadedPath):
			for filename in filenames:
				imagepath = os.path.join(dirname, filename)

				if fileCount < maxFileCount:
					logging.debug("Sending to image server:  " + imagepath)
					call (['scp', imagepath, remoteHost + ":" + userRemoteStagingPath])
					call (['mv', imagepath, userProcessingPath])
					fileCount += 1

				if (fileCount >= countBeforeStartStep3 and not step3Started):
					startStep3(remoteHost, step3Script)
					step3Started = True;

	# If we havn't started it yet (didn't hit needed file count) then start step3
	if (fileCount == 0):
		logging.info("No images to process")

	if (not step3Started):
		startStep3(remoteHost, step3Script)

def handler(clientsock,addr):
	BUFSIZ = 1024

	while 1:
		data = clientsock.recv(BUFSIZ)
		if not data:
			break
		msg = 'echoed:... ' + data
		clientsock.send(msg)
	clientsock.close()


def main(argv):
	basePath = '/home/derektes/public_html/photos/turnip/pipeline'
	uploadedDir = 'uploads'
	stagingDir = 'staging'
	processingDir = 'processing'
	processedDir = 'processed'
	outputDir = 'output'
	remoteHost = 'derek@asood123.no-ip.biz'
	remoteBasePath = '/home/derek/pipeline'

	step3Script = "/home/derek/Duffy/turnip/scripts/step3.py"

	socketHost = 'localhost'
	socketPort = 5555

	userIdToProcess = ''
	waitOnPort = False

	try:
		opts, args = getopt.getopt(argv,"hpi:",["port=", "id="])
	except getopt.GetoptError:
		print 'step2.py -p -i <userId>'
		sys.exit(2)

	for opt, arg in opts:
		if opt == '-h':
			print 'step2.py -p <port>'
			sys.exit()
		elif opt in '-p':
			waitOnPort = True
		elif opt in ("-i", "--id"):
			userIdToProcess = arg

	maxFileCount = 4
	countBeforeStartStep3 = 2

	uploadedPath = os.path.join(basePath, uploadedDir)
	processingPath = os.path.join(basePath, processingDir)


	logging.basicConfig(filename=os.path.join(os.path.dirname(os.path.realpath(__file__)),'step2.log'), level=logging.DEBUG)
 	logging.debug("Starting Step2")

 	if (waitOnPort):
		serversock = socket(AF_INET, SOCK_STREAM)
		serversock.bind((socketHost, socketPort))
		serversock.listen(2)
		while 1:
			print 'waiting for connection...'
			clientsock, addr = serversock.accept()
			print '...connected from:', addr
			thread.start_new_thread(handler, (clientsock, addr))

	userIds = list()
	if (userIdToProcess):
		userIds.append(userIdToProcess)
	else:
		userIds = getUserIds(uploadedPath)


	logging.debug("Running step2 with ids:  " + str(userIds))
	startStep2(userIds, maxFileCount, countBeforeStartStep3, step3Script, uploadedPath, processingPath, stagingDir, remoteHost, remoteBasePath)

	logging.debug("Done with Step 2")
if __name__ == "__main__":
	main(sys.argv[1:])
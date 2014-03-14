#!/usr/bin/python
# Copies files from the "uploaded" directory to duffy/staging then moves local files to "processing"

import sys, getopt, os
from subprocess import call

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

	try:
		opts, args = getopt.getopt(argv,"hb:d:r:",["bpath=","rbase=","dhost="])
	except getopt.GetoptError:
		print 'step2.py -b <base path> -rh <remote host> -rb <remote base path>'
		sys.exit(2)

	for opt, arg in opts:
		if opt == '-h':
			print 'step2.py -b <base path> -rh <remote host> -rb <remote base path>'
			sys.exit()
		elif opt in ("-b", "--bpath"):
			duffyHost = arg
		elif opt in ("-d", "--dhost"):
			duffyHost = arg
		elif opt in ("-r", "--rbase"):
			remoteBasePath = arg

	print 'basePath is ', basePath
	print 'uploadeddir is ', uploadedDir
	print 'processingdir is ', processingDir
	print 'stagingdir is ', stagingDir
	print 'remoteHost is', remoteHost
	print 'remoteBasePath is', remoteBasePath

	fileCount = 0
	maxFileCount = 2

	uploadedPath = os.path.join(basePath, uploadedDir)
	processingPath = os.path.join(basePath, processingDir)
	stagingPath = os.path.join(basePath, stagingDir)

	for dirname, dirnames, filenames in os.walk(uploadedPath):
		# Each subdir is a userId
		for userId in dirnames:
			print 'Processing: ', userId

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
						print "Sending to Duffy:  ", imagepath
						call (['scp', imagepath, remoteHost + ":" + userRemoteStagingPath])
						call (['mv', imagepath, userProcessingPath])
						fileCount += 1

	print "Sending command to process " + str(fileCount) + " files"
	call (['ssh', remoteHost, step3Script])

if __name__ == "__main__":
	main(sys.argv[1:])
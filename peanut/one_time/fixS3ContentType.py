#!/usr/bin/python
import sys, os, requests, json
import pytz
import logging, boto
from datetime import datetime, date, timedelta
from dateutil.relativedelta import relativedelta

from django.core.files.storage import default_storage
from boto.s3.connection import S3Connection
from boto.s3.key import Key

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.conf import settings



def getStatsForBucket(bucket):
	badContentTypeCount = goodContentTypeCount = otherCount = 0

	start = datetime.now()
	keys = bucket.list()
	for key in keys:
		curKey = bucket.get_key(key.name)
		if 'octet-stream' in str(curKey.content_type):
			badContentTypeCount +=1
		elif 'image/jpeg' in str(curKey.content_type):
			goodContentTypeCount +=1
		else:
			otherCount +=1
			print '%s: %s'%(curKey.name, curKey.content_type)
		print 'good: %s | bad: %s | other: %s'%(goodContentTypeCount, badContentTypeCount, otherCount)

	print "octet-stream: %s"%(badContentTypeCount)
	print "image/jpeg: %s"%(goodContentTypeCount)
	print "others: %s"%(otherCount)

	print "Total time: %s"%(datetime.now() - start)

def fixKeys(bucket):
	goodContentTypeCount = 0
	fixedkeysCount = 0

	start = datetime.now()

	keys = bucket.list()
	
	for key in keys:
		curKey = bucket.get_key(key.name)
		if 'image/jpeg' in str(curKey.content_type):
			goodContentTypeCount +=1		
		else:
			fixedkeysCount += 1
			key.copy(key.bucket, key.name, preserve_acl=True, metadata={'Content-Type': 'image/jpeg'})
		print 'Goodkeys: %s | fixedkeys: %s'%(goodContentTypeCount, fixedkeysCount)

	print "image/jpeg: %s"%(goodContentTypeCount)
	print "Fixed: %s"%(fixedkeysCount)

	print "Total time: %s"%(datetime.now() - start)


# This script identifies all files on s3 without content-type 'image/jpeg' and fixes them
def main(argv):
	print 'Starting...'

	start = datetime.now()

	s3 = boto.connect_s3(settings.AWS_ACCESS_KEY_ID, settings.AWS_SECRET_ACCESS_KEY)
	bucket = s3.lookup(settings.AWS_STORAGE_BUCKET_NAME)

	# Uncomment this to get stats on a bucket
	getStatsForBucket(bucket)

	# Uncomment this to fix keys in a bucket
	#fixKeys(bucket)



		
if __name__ == "__main__":

	main(sys.argv[1:])
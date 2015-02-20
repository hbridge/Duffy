from __future__ import absolute_import
import logging
import datetime

from django.core.mail import EmailMessage, EmailMultiAlternatives

from peanut.celery import app

from celery.utils.log import get_task_logger
logger = get_task_logger(__name__)

def sendEmail(emailSubj, dataDict, emailToList):
	logging.getLogger('django.db.backends').setLevel(logging.ERROR)
	total = 0
	processedCount = 1
	startTime = datetime.datetime.utcnow()

	email = EmailMultiAlternatives(emailSubj, str(dataDict), 'prod@duffyapp.com',emailToList, 
		[], headers = {'Reply-To': 'support@duffytech.co'})	
	email.send(fail_silently=False)
	logger.info('Email Sent to: ' + ' '.join(emailToList))

	endTime = datetime.datetime.utcnow()
	msTime = ((endTime-startTime).microseconds / 1000 + (endTime-startTime).seconds * 1000)
	return (total, "%s ms" % msTime)	

@app.task
def sendEmailForIncomingSMS(dataDict):
	subject = 'Incoming SMS'
	if 'from' in dataDict:
		subject += ": " + dataDict['from']
	sendEmail(subject, dataDict, ['support@duffytech.co'])
	return 1
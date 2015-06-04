from __future__ import absolute_import

from celery import Celery
from django.conf import settings

app = Celery('peanut',
			 backend='amqp://',
			 include=[#'async.two_fishes',
					  #'async.stranding',
					  #'async.similarity',
					  #'async.popcaches',
					  #'async.neighboring',
					  #'async.friending',
					  #'async.suggestion_notifications',
					  #'async.notifications',
					  #'async.internal',
					  'memfresh.async',
					  'smskeeper.async',
					  'smskeeper.sms_util'])

app.config_from_object(settings.CELERY_CONFIG)

if __name__ == '__main__':
	app.start()
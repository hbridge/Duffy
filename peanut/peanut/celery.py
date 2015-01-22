from __future__ import absolute_import

from celery import Celery

app = Celery('peanut',
			 broker='amqp://',
			 backend='amqp://',
			 include=['async.tasks',
					  'async.two_fishes'])

app.config_from_object('django.conf:settings')

# Optional configuration, see the application user guide.
app.conf.update(
	CELERY_TASK_RESULT_EXPIRES=3600,
)

if __name__ == '__main__':
	app.start()
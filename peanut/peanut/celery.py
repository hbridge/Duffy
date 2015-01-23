from __future__ import absolute_import

from celery import Celery

app = Celery('peanut',
			 broker='amqp://',
			 backend='amqp://',
			 include=['async.two_fishes',
					  'async.stranding',
					  'async.similarity'])

app.config_from_object('django.conf:settings')

# Optional configuration, see the application user guide.
app.conf.update(
	CELERY_TASK_RESULT_EXPIRES=3600,
)
"""
CELERY_QUEUES = (
	Queue('default', Exchange('default'), routing_key='default'),
	Queue('for_two_fishes', Exchange('for_two_fishes'), routing_key='for_two_fishes'),
	Queue('for_stranding', Exchange('for_stranding'), routing_key='for_stranding'),
)

CELERY_ROUTES = {
	'async.two_fishes.processList': {'queue': 'for_two_fishes', 'routing_key': 'for_two_fishes'},
	'async.stranding.processList': {'queue': 'for_stranding', 'routing_key': 'for_stranding'},
}
"""
if __name__ == '__main__':
	app.start()
from __future__ import absolute_import

from kombu import Exchange, Queue

from celery import Celery

app = Celery('peanut',
			 broker='amqp://',
			 backend='amqp://',
			 include=['async.two_fishes',
					  'async.stranding',
					  'async.similarity',
					  'async.popcaches',
					  'async.neighboring'])

app.config_from_object('django.conf:settings')

# Optional configuration, see the application user guide.
app.conf.update(
	CELERY_TASK_RESULT_EXPIRES=3600,
	CELERYD_CONCURRENCY=4,
	CELERY_QUEUES = (
		Queue('default', Exchange('default'), routing_key='default'),
		Queue('for_two_fishes', Exchange('for_two_fishes'), routing_key='for_two_fishes'),
		Queue('for_stranding', Exchange('for_stranding'), routing_key='for_stranding'),
		Queue('for_popcaches', Exchange('for_popcaches'), routing_key='for_popcaches'),
		Queue('for_popcaches_full', Exchange('for_popcaches_full'), routing_key='for_popcaches_full'),
		Queue('for_similarity', Exchange('for_similarity'), routing_key='for_similarity'),
		Queue('for_neighboring', Exchange('for_neighboring'), routing_key='for_neighboring'),
	),
	CELERY_ROUTES = {
		'async.two_fishes.processAll': {'queue': 'for_two_fishes', 'routing_key': 'for_two_fishes'},
		'async.two_fishes.processIds': {'queue': 'for_two_fishes', 'routing_key': 'for_two_fishes'},
		'async.stranding.processAll': {'queue': 'for_stranding', 'routing_key': 'for_stranding'},
		'async.stranding.processIds': {'queue': 'for_stranding', 'routing_key': 'for_stranding'},
		'async.popcaches.processAll': {'queue': 'for_popcaches', 'routing_key': 'for_popcaches'},
		'async.popcaches.processIds': {'queue': 'for_popcaches', 'routing_key': 'for_popcaches'},
		'async.popcaches.processFull': {'queue': 'for_popcaches_full', 'routing_key': 'for_popcaches_full'},
		'async.similarity.processAll': {'queue': 'for_similarity', 'routing_key': 'for_similarity'},
		'async.similarity.processIds': {'queue': 'for_similarity', 'routing_key': 'for_similarity'},
		'async.neighboring.processAllStrands': {'queue': 'for_neighboring', 'routing_key': 'for_neighboring'},
		'async.neighboring.processStrandIds': {'queue': 'for_neighboring', 'routing_key': 'for_neighboring'},
		'async.neighboring.processAllLocationRecords': {'queue': 'for_neighboring', 'routing_key': 'for_neighboring'},
		'async.neighboring.processLocationRecordIds': {'queue': 'for_neighboring', 'routing_key': 'for_neighboring'},
	}
)


if __name__ == '__main__':
	app.start()
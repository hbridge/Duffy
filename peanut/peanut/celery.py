from __future__ import absolute_import

from kombu import Exchange, Queue

from celery import Celery

app = Celery('peanut',
			 broker='amqp://',
			 backend='amqp://',
			 include=['async.two_fishes',
					  'async.stranding',
					  'async.similarity',
					  'async.popcaches'])

app.config_from_object('django.conf:settings')

# Optional configuration, see the application user guide.
app.conf.update(
	CELERY_TASK_RESULT_EXPIRES=3600,
	CELERYD_CONCURRENCY=4,
	CELERY_QUEUES = (
		Queue('default', Exchange('default'), routing_key='default'),
		Queue('for_two_fishes', Exchange('for_two_fishes'), routing_key='for_two_fishes'),
		Queue('for_stranding', Exchange('for_stranding'), routing_key='for_stranding'),
		Queue('for_popcache', Exchange('for_popcache'), routing_key='for_popcache'),
		Queue('for_popcache_full', Exchange('for_popcache_full'), routing_key='for_popcache_full'),
		Queue('for_similarity', Exchange('for_similarity'), routing_key='for_similarity'),
	),
	CELERY_ROUTES = {
		'async.two_fishes.processAll': {'queue': 'for_two_fishes', 'routing_key': 'for_two_fishes'},
		'async.stranding.processAll': {'queue': 'for_stranding', 'routing_key': 'for_stranding'},
		'async.popcache.processAll': {'queue': 'for_popcache', 'routing_key': 'for_popcache'},
		'async.popcache.processFull': {'queue': 'for_popcache_full', 'routing_key': 'for_popcache_full'},
		'async.similarity.processAll': {'queue': 'for_similarity', 'routing_key': 'for_similarity'},
	}
)


if __name__ == '__main__':
	app.start()
#!/bin/bash

if [ "$1" == "start" ]
then
	python manage.py celeryd_multi start independent stranding popcaches ordered_low -B --logfile=/mnt/log/celery-%N.log --pidfile=/mnt/log/celery-%N.pid -c 1 -c:independent 10 -Q:independent independent -Q:stranding stranding -Q:popcaches popcaches -Q:ordered_low ordered_low
else
	python manage.py celeryd_multi stop independent stranding popcaches ordered_low -B --logfile=/mnt/log/celery-%N.log --pidfile=/mnt/log/celery-%N.pid
fi	
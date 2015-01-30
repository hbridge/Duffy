#!/bin/bash

if [ "$2" == "dev" ]
then
	export DJANGO_SETTINGS_MODULE=peanut.settings.dev
	cd /home/ubuntu/dev/Duffy/peanut
elif [[ "$2" == "prod" ]]; then
	export DJANGO_SETTINGS_MODULE=peanut.settings.prod
	cd /home/ubuntu/Duffy/peanut
fi

if [ "$1" == "start" ]
then
	/home/ubuntu/env/bin/python manage.py celeryd_multi start independent stranding popcaches ordered_low -B --logfile=/mnt/log/celery-%N.log --pidfile=/mnt/run/celery-%N.pid -c 1 -c:independent 10 -Q:independent independent -Q:stranding stranding -Q:popcaches popcaches -Q:ordered_low ordered_low
else
	/home/ubuntu/env/bin/python manage.py celeryd_multi stop independent stranding popcaches ordered_low -B --logfile=/mnt/log/celery-%N.log --pidfile=/mnt/run/celery-%N.pid
fi	
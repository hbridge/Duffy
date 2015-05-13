#!/bin/bash

# Really really need this because the upstart script runs as another user so need to setup the virtualenv
PYTHON=/home/ubuntu/env/bin/python

if [ "$2" == "dev" ]
then
	export DJANGO_SETTINGS_MODULE=peanut.settings.dev
	cd /home/ubuntu/dev/Duffy/peanut
elif [[ "$2" == "prod" ]]; then
	export DJANGO_SETTINGS_MODULE=peanut.settings.prod
	cd /home/ubuntu/Duffy/peanut
elif [[ "$2" == "local" ]]; then
	export DJANGO_SETTINGS_MODULE=peanut.settings.local
	cd /Users/hbridge/Documents/Repos/Duffy/peanut
	PYTHON=python
fi

if [ "$1" == "start" ]
then
	$PYTHON manage.py celeryd_multi start keeper --logfile=/mnt/log/celery-%N.log --pidfile=/mnt/run/celery-%N.pid -c 1 -c:keeper 5 -Q:keeper keeper
else
	$PYTHON manage.py celeryd_multi stop keeper --logfile=/mnt/log/celery-%N.log --pidfile=/mnt/run/celery-%N.pid
fi

if [ "$1" == "killall" ]
then
	ps auxww | grep "celery worker" | awk '{print $2}' | xargs sudo kill -9
fi

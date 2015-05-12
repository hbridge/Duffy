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
	/home/ubuntu/env/bin/python manage.py celeryd_multi start keeper --logfile=/mnt/log/celery-%N.log --pidfile=/mnt/run/celery-%N.pid -c 1 -c:keeper 5 -Q:keeper keeper
else
	/home/ubuntu/env/bin/python manage.py celeryd_multi stop keeper --logfile=/mnt/log/celery-%N.log --pidfile=/mnt/run/celery-%N.pid
fi

if [ "$1" == "killall" ]
then
	ps auxww | grep "celery worker" | awk '{print $2}' | xargs sudo kill -9
fi

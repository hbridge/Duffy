#!/bin/bash

cd /home/derek/prod/Duffy/peanut
while true
do
	python manage.py update_index --age=1
	sleep 5
done
#!/bin/sh

# Script to run simulation tests

cd /home/ubuntu/dev/Duffy
git fetch
git rebase origin/master
cd peanut
DJANGO_SETTINGS_MODULE=peanut.settings.dev /home/ubuntu/env/bin/python manage.py test smskeeper.scripts.simulate.devNightly

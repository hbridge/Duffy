#!/bin/bash

# Script to restart all Duffy services, should be called by a cron, probably nightly
#
# Needed because long running python scripts have memory leaks.
#
service duffy-faces stop
sleep 1
service duffy-faces start

sleep 5

service duffy-twofishes stop
sleep 1
service duffy-twofishes start

sleep 5

service duffy-classifier stop
sleep 1
service duffy-classifier start

sleep 5

service duffy-neighbor stop
sleep 1
service duffy-neighbor start

sleep 5

service duffy-similarity stop
sleep 1
service duffy-similarity start

sleep 5

service duffy-strand-notifications stop
sleep 1
service duffy-strand-notifications start
#!/bin/bash

# Script to restart all Duffy services, should be called by a cron, probably nightly
#
# Needed because long running python scripts have memory leaks.
#
/usr/bin/service duffy-faces stop
sleep 1
/usr/bin/service duffy-faces start

sleep 5

/usr/bin/service duffy-twofishes stop
sleep 1
/usr/bin/service duffy-twofishes start

sleep 5

/usr/bin/service duffy-classifier stop
sleep 1
/usr/bin/service duffy-classifier start

sleep 5

/usr/bin/service duffy-neighbor stop
sleep 1
/usr/bin/service duffy-neighbor start

sleep 5

/usr/bin/service duffy-similarity stop
sleep 1
/usr/bin/service duffy-similarity start

sleep 5

/usr/bin/service duffy-strand-notifications stop
sleep 1
/usr/bin/service duffy-strand-notifications start
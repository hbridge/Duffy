#!/bin/sh

# Script to restart all Duffy services, should be called by a cron, probably nightly
#
# Needed because long running python scripts have memory leaks.
#

echo $PATH
whoami

/usr/sbin/service duffy-faces stop
sleep 1
/usr/sbin/service duffy-faces start

sleep 5

/usr/sbin/service duffy-twofishes stop
sleep 1
/usr/sbin/service duffy-twofishes start

sleep 5

/usr/sbin/service duffy-classifier stop
sleep 1
/usr/sbin/service duffy-classifier start

sleep 5

/usr/sbin/service duffy-neighbor stop
sleep 1
/usr/sbin/service duffy-neighbor start

sleep 5

/usr/sbin/service duffy-similarity stop
sleep 1
/usr/sbin/service duffy-similarity start

sleep 5

/usr/sbin/service duffy-strand-notifications stop
sleep 1
/usr/sbin/service duffy-strand-notifications start
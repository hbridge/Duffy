#!/bin/sh

# Script to restart all Duffy services, should be called by a cron, probably nightly
#
# Needed because long running python scripts have memory leaks.
#

/sbin/initctl stop duffy-faces
sleep 1
/sbin/initctl start duffy-faces

sleep 5

/sbin/initctl stop duffy-twofishes
sleep 1
/sbin/initctl start duffy-twofishes

sleep 5

/sbin/initctl stop duffy-classifier
sleep 1
/sbin/initctl start duffy-classifier

sleep 5

/sbin/initctl stop duffy-similarity
sleep 1
/sbin/initctl start duffy-similarity

sleep 5

/sbin/initctl stop duffy-stranding
sleep 1
/sbin/initctl start duffy-stranding

sleep 5

/sbin/initctl stop duffy-friends
sleep 1
/sbin/initctl start duffy-friends


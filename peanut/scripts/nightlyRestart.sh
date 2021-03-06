#!/bin/sh

# Script to restart all Duffy services, should be called by a cron, probably nightly
#
# Needed because long running python scripts have memory leaks.
#

/sbin/initctl stop duffy-twofishes
sleep 1
/sbin/initctl start duffy-twofishes

sleep 5

/sbin/initctl stop duffy-similarity
sleep 1
/sbin/initctl start duffy-similarity

sleep 5

/sbin/initctl stop duffy-stranding
sleep 1
/sbin/initctl start duffy-stranding

sleep 5

/sbin/initctl stop duffy-neighboring
sleep 1
/sbin/initctl start duffy-neighboring

sleep 5

/sbin/initctl stop duffy-friends
sleep 1
/sbin/initctl start duffy-friends

sleep 5

/sbin/initctl stop duffy-strand-notifications
sleep 1
/sbin/initctl start duffy-strand-notifications

sleep 5

/sbin/initctl stop duffy-popcaches
sleep 1
/sbin/initctl start duffy-popcaches

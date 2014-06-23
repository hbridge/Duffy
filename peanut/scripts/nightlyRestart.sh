#!/bin/bash

# Script to restart all Duffy services, should be called by a cron, probably nightly
#
# Needed because long running python scripts have memory leaks.
#
stop duffy-faces
sleep 1
start duffy-faces

sleep 5

stop duffy-overfeat
sleep 1
start duffy-overfeat

sleep 5

stop duffy-twofishes
sleep 1
start duffy-twofishes

sleep 5

stop duffy-classifier
sleep 1
start duffy-classifier

sleep 5

stop duffy-neighbor
sleep 1
start duffy-neighbor

sleep 5

stop duffy-similarity
sleep 1
start duffy-similarity

sleep 5

stop duffy-strand-notifications
sleep 1
start duffy-strand-notifications
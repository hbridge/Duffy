#!/usr/bin/python
import sys, os, requests, json
import pytz
import logging
from datetime import datetime, date, timedelta
from dateutil.relativedelta import relativedelta
import gdata.spreadsheet.service

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
	sys.path.insert(0, parentPath)
import django
django.setup()

from django.core.mail import EmailMessage, EmailMultiAlternatives
from django.db.models import Count, Sum
from django.db.models import Q

from peanut.settings import constants
from common.models import User, FriendConnection, Action, Photo, StrandNeighbor

def getActionsListForUserId(userId, count=1000):
	actionList = list(Action.objects.filter(user=userId).filter(action_type=5).order_by('added')[:count])
	print "Actions found: %s"%(len(actionList))
	return actionList

def getDuplicateEvals(actionList):

	# count number of unique photos
	photoList = dict()
	dupActionsList = list()
	for action in actionList:
		if action.photo.id in photoList:
			photoList[action.photo.id] += 1
			dupActionsList.append(action)
		else:
			photoList[action.photo.id] = 1

	print "Unique photos found: %s"%(len(photoList))
	print "Actions to delete: %s"%(len(dupActionsList))

	return dupActionsList

def deleteActions(deleteActionsList, deleteForReal=False):

	actionsDeleted = 0
	for action in deleteActionsList:
		if deleteForReal:
			action.delete()
		actionsDeleted +=1

	if deleteForReal:
		print "Actions deleted: %s"%(actionsDeleted)
	else:
		print "Actions that could be deleted: %s"%(actionsDeleted)

	return actionsDeleted


# This script remove photo_eval actions that duplicates (same photo_id, same strand_id and same user_id)
def main(argv):
	print 'Starting...'

	totalActionsToDelete = 0

	users = User.objects.filter(product_id=2)

	for user in users:
		print "UserId: %s"%(user.id)
		actionList = getActionsListForUserId(user.id)
		dupActionList = getDuplicateEvals(actionList)
		totalActionsToDelete += deleteActions(dupActionList, False) # Change to true to delete actions

	print totalActionsToDelete

		
if __name__ == "__main__":

	main(sys.argv[1:])
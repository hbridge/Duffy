import sys
import json
import os

parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)
import django
django.setup()

from django.shortcuts import render
from django.db.models import Q
from django.http import HttpResponse

from peanut.settings import constants
from common.models import Photo, User, Action, Strand, ShareInstance

from strand import strands_util

# 83928

"""
Go through all strand post actions that affect public strands that the user is in

"""
def main(argv):
    actions = Action.objects.prefetch_related('photo').all()

    for action in actions:
        if action.action_type == constants.ACTION_TYPE_PHOTO_EVALUATED and action.user_id == action.photo.user_id:
            action.photo.owner_evaluated = True
            action.photo.save()

        print "finished with action %s" % action.id

if __name__ == "__main__":
    main(sys.argv[1:])
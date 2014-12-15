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
from common.models import Photo, User, Action, Strand

"""
Go through all strand post actions that affect public strands that the user is in

"""
def main(argv):
    maxFileCount = 10000
    maxFileAtTime = 16
    count = 0

    userIds = [5009]


    for userId in userIds:
        user = User.objects.get(id=userId)
        print "Starting populate eval"
        # Get all photos in pipeline_state 0 which means "not copied to image server"
        strands = Strand.objects.filter(users__in=[userId]).filter(private=False)
        
        strandIds = Strand.getIds(strands)

        actions = Action.objects.prefetch_related('photos').filter(strand__in=strandIds).filter(Q(action_type=constants.ACTION_TYPE_CREATE_STRAND) | Q(action_type=constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND) | Q(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED))

        alreadyEvaledIds = list()

        for action in actions:
            if action.action_type == constants.ACTION_TYPE_PHOTO_EVALUATED and action.user_id == user.id:
                alreadyEvaledIds.append(action.photo_id)

        for action in actions:
            for photo in action.photos.all():
                if photo.id not in alreadyEvaledIds:
                    newAction = Action(user=user, strand=action.strand, photo_id=photo.id, action_type=constants.ACTION_TYPE_PHOTO_EVALUATED)
                    newAction.save()
                    newAction.added = action.added
                    newAction.updated = action.updated
                    newAction.save()
                    print "%s" % newAction.id


        

if __name__ == "__main__":
    main(sys.argv[1:])
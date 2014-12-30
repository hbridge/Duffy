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


def convertStrandToShareInstance(strand):
    strandActions = Action.objects.filter(strand_id=strand.id)

    for photo in strand.photos.all():
        addAction = None
        for action in strandActions:
            if action.action_type == constants.ACTION_TYPE_CREATE_STRAND or action.action_type == constants.ACTION_TYPE_ADD_PHOTOS_TO_STRAND and photo in action.photos.all():
                addAction = action

        if not addAction:
            print "couldn't find add action for %s %s" % (photo.id, strand.id)
            return False

        photoActions = Action.objects.filter(photo_id=photo.id)

        lastTimeStamp = addAction.added
        actionsForThisShare = list()
        for action in photoActions:
            if action.strand_id == strand.id or (action.user == photo.user and action.action_type == constants.ACTION_TYPE_PHOTO_EVALUATED):
                actionsForThisShare.append(action)

            if action.action_type == constants.ACTION_TYPE_COMMENT or action.action_type == constants.ACTION_TYPE_FAVORITE:
                if not lastTimeStamp:
                    lastTimeStamp = action.added
                elif lastTimeStamp < action.added:
                    lastTimeStamp = action.added

        shareInstance = ShareInstance.objects.create(user=photo.user, photo = photo, shared_at_timestamp=addAction.added, last_action_timestamp=lastTimeStamp)
        shareInstance.users = User.getIds(strand.users.all())

        for action in actionsForThisShare:
            action.share_instance = shareInstance
            action.save()

    return True




"""
Go through all strand post actions that affect public strands that the user is in

"""
def main(argv):
    maxFileCount = 10000
    maxFileAtTime = 16
    count = 0

    strands = Strand.objects.prefetch_related('photos', 'users').filter(swap_converted=False).filter(private=False).order_by('-id')[:1000]

    for strand in strands:
        if len(strand.users.all()) == 1:
            print "Skipping strand %s since it only has one user" % strand.id
            continue
            
        print "Starting converstion for strand %s" % strand.id
        
        ret = convertStrandToShareInstance(strand)

        if ret:
            strand.swap_converted = True
            strand.save()
            print "Successfully converted %s" % strand.id


if __name__ == "__main__":
    main(sys.argv[1:])
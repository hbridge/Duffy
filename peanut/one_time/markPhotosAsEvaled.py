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
    shareInstances = ShareInstance.objects.prefetch_related('users', 'photo').all()

    #shareInstances = ShareInstance.objects.prefetch_related('users', 'photo').filter(id=560)

    print shareInstances.query
    print shareInstances
    
    for shareInstance in shareInstances:
        photoActions = Action.objects.filter(photo_id = shareInstance.photo_id).filter(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED)
        shareInstanceActions = Action.objects.filter(share_instance_id = shareInstance.id).filter(action_type=constants.ACTION_TYPE_PHOTO_EVALUATED)

        created = dict()

        for photoAction in photoActions:
            found = False
            for shareInstanceAction in shareInstanceActions:
                if shareInstanceAction.user_id == photoAction.user_id:
                    found = True

            if not photoAction.user_id in created and not found and photoAction.user_id != shareInstance.user_id:
                newAction = Action.objects.create(user_id=photoAction.user_id, action_type=constants.ACTION_TYPE_PHOTO_EVALUATED, photo_id  = photoAction.photo_id, share_instance_id = shareInstance.id)
                
                if photoAction.added > shareInstance.added:
                    newAction.added = photoAction.added
                else:
                    newAction.added = shareInstance.added
                newAction.save()

                print "Created action %s for photo %s and user %s" % (newAction.id, newAction.photo_id, newAction.user_id)
                created[photoAction.user_id] = True
        print "Finished with share instance %s" % shareInstance.id


if __name__ == "__main__":
    main(sys.argv[1:])
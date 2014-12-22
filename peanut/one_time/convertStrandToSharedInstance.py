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

from strand import strands_util

"""
Go through all strand post actions that affect public strands that the user is in

"""
def main(argv):
    maxFileCount = 10000
    maxFileAtTime = 16
    count = 0

    strands = Strand.objects.prefetch_related('photos').filter(swap_converted=False).filter(private=False).order_by('-id')[:1]

    for strand in strands:
        print "Starting converstion for strand %s" % strand.id
        
        ret = strands_util.convertStrandToShareInstance(strand)

        if ret:
            strand.swap_converted = True
            strand.save()
            print "Successfully converted %s" % strand.id


if __name__ == "__main__":
    main(sys.argv[1:])
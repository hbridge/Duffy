import os, sys
parentPath = os.path.join(os.path.split(os.path.abspath(__file__))[0], "..")
if parentPath not in sys.path:
    sys.path.insert(0, parentPath)

import django
django.setup()
import smskeeper
from django.db.models.query import QuerySet
from smskeeper.forms import UserIdForm, SmsContentForm, PhoneNumberForm, SendSMSForm
from smskeeper.models import User, Note, NoteEntry, Message, MessageMedia, Entry, EntryLink
from peanut.settings import constants
from pprint import PrettyPrinter


import json
from django.core.serializers.json import DjangoJSONEncoder

def printDjango(obj):
    model._meta.get_all_field_names()

def main(argv):
    for note in Note.objects.all():
        print "migrating: %s/%s" % (note.user.phone_number, note.label)
        for noteEntry in NoteEntry.objects.filter(note=note):
            #print(noteEntry.__dict__)
            #create a new entry object
            entry = Entry.objects.create(creator=note.user)
            for attribute in ["text", "img_url", "remind_timestamp", "hidden", "keeper_number", "added", "updated"]:
                setattr(entry, attribute, getattr(noteEntry, attribute))
            entry.save()

            entryLink = EntryLink.objects.create(
                label=note.label,
                entry=entry,
                added=entry.added,
                updated=entry.updated
            )

            entryLink.users.add(note.user)
            entryLink.save()




if __name__ == "__main__":
    main(sys.argv[1:])

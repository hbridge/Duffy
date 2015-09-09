from datetime import date, timedelta
from smskeeper.models import Message, User
from smskeeper import keeper_constants

dateFilter = date.today() - timedelta(days=7)

productIdList = [0,1]

activatedUsersAll= User.objects.filter(activated__lt=dateFilter, product_id__in=productIdList)
activatedUsersFB = User.objects.filter(activated__lt=dateFilter, product_id__in=productIdList, signup_data_json__icontains='fb')

usersAll = Message.objects.values('user__name').filter(incoming=True, added__gt=dateFilter, user__product_id__in=productIdList, user__activated__lt=dateFilter, user__completed_tutorial=True).exclude(user__state=keeper_constants.STATE_STOPPED).distinct()

usersFB = Message.objects.values('user__name').filter(incoming=True, added__gt=dateFilter, user__product_id__in=productIdList, user__completed_tutorial=True, user__in=activatedUsersFB, user__signup_data_json__icontains='fb').exclude(user__state=keeper_constants.STATE_STOPPED).distinct()

usersStopped = User.objects.filter(activated__lt=dateFilter, product_id__in=productIdList, state=keeper_constants.STATE_STOPPED)

print "Total users activated: %s (FB: %s)" %(len(activatedUsersAll), len(activatedUsersFB))
print "Active users: %s (FB: %s)"%(len(usersAll), len(usersFB))
print "%% actives: %s%% (FB: %s%%)"%(float(len(usersAll))/float(len(activatedUsersAll))*100.0, float(len(usersFB))/float(len(activatedUsersFB))*100.0)
print "Stopped users: %s"%(len(usersStopped))


# query to get sorted list of incoming count by users

from smskeeper.models import Message, Entry
from django.db.models import Count
from datetime import date, timedelta

dateFilter = date.today() - timedelta(days=45)
users = Message.objects.values_list('user__id', 'user__name').filter(incoming=True, user__completed_tutorial=True, added__gt=dateFilter).annotate(total_incoming=Count('user__id')).order_by('total_incoming')

for entry in users:
    print "%s %s: %s"%(entry[0], entry[1], entry[2])


# query to find out who has created most entries

from smskeeper.models import Message, Entry
from django.db.models import Count

entries = Entry.objects.values_list('creator_id', 'creator__name').filter(label='#reminders').annotate(total=Count('creator')).order_by('total')

for entry in entries:
    print "%s %s: %s"%(entry[0], entry[1], entry[2])

# query to find users who have many entries not in reminders

from smskeeper.models import Message, User, Entry
from django.db.models import Count

entries = Entry.objects.values_list('creator__id', 'creator__name').exclude(label='#reminders').annotate(totalCount=Count('creator__id')).order_by('-totalCount')

for entry in entries:
    print "%s %s: %s"%(entry[0], entry[1],entry[2])


# query to get last n reminder inputs

from smskeeper.models import Message, Entry
import json

reminderMsgs = Message.objects.filter(msg_json__icontains='remind me', incoming=True).exclude(msg_json__icontains='#').order_by('-added')
reminderMsgs = Entry.objects.filter(label='#reminders', hidden=False).order_by('-added')[:200]

print len(reminderMsgs)

for msg in reminderMsgs:
    print json.loads(msg.orig_text)[0]


# query to get a blacklist of words that are follow "Remind" for shared reminders

from smskeeper.models import Message
import json, operator

reminderMsgs = Message.objects.filter(msg_json__icontains='remind', incoming=True).exclude(msg_json__icontains='#').order_by('-added')

print len(reminderMsgs)

wordList = dict()

for msg in reminderMsgs:
    body = json.loads(msg.msg_json)['Body']
    index = body.lower().find('remind ')
    if index >= 0:
        splitSpring = body[index:].split()
        if len(splitSpring) > 1:
            #print str(msg.id) + " " + splitSpring[0] + ": " + splitSpring[1]
            if splitSpring[1] in wordList:
                wordList[splitSpring[1]] += 1
            else:
                wordList[splitSpring[1]] = 1
    #else:
    #    print str(index) + " " + body


sortedList = sorted(wordList.items(), key=operator.itemgetter(1), reverse=True)

for entry, count in sortedList:
    print entry + " " + str(count)


# Print out messages that users sent that paused them.

from smskeeper.models import Message
from smskeeper import keeper_constants
import json

msgs = Message.objects.filter(auto_classification=keeper_constants.CLASS_UNKNOWN)

for msg in msgs:
    nextMsgs = Message.objects.filter(user=msg.user).filter(id__gt=msg.id)
    body = json.loads(msg.msg_json)['Body']
    print "%s: %s, %s"%(msg.id, msg.added, body)
    for n in nextMsgs:
        if n.manual == True or n.incoming == False:
            break
        nbody = json.loads(n.msg_json)['Body']
        print "%s: %s, %s"%(n.id, n.added, nbody)
    print '\n\n'



# Figure out organic growth on monthly basis

from smskeeper.models import User
import datetime, pytz, json

def countReferredUsers(userList):
    count = 0
    for user in userList:
        if user.signup_data_json:
            data = json.loads(user.signup_data_json)
            if 'referrer' in data:
                referrer = data['referrer']
                if len(referrer) > 2:
                    count += 1
    return count

def countUsers(userList):
    refCount = 0
    defaultCount = 0
    fbCount = 0
    nojsCount = 0
    txtedUsCount = 0
    noSourceCount = 0
    reminderCount = 0
    otherCount = 0
    for user in userList:
        if user.signup_data_json:
            data = json.loads(user.signup_data_json)
            if 'referrer' in data:
                referrer = data['referrer']
                if len(referrer) > 2:
                    refCount += 1
                    continue
            if 'source' in data:
                source = data['source']
                if 'fb' in source:
                    fbCount +=1
                    continue
                if 'no-js' in source:
                    nojsCount += 1
                    continue
                if 'reminder' in source:
                    reminderCount +=1
                    continue
                if len(source) == 0 or 'default' in source:
                    defaultCount += 1
                    continue
            else:
                txtedUsCount += 1
                continue
        else:
            noSourceCount +=1
            continue
        otherCount +=1
    print "%d\t Total users added"%(len(userList))
    print "%d\t From facebook [PAID]"%(fbCount)
    print "%d\t Source 'no-js [PAID - mostly]'"%(nojsCount)
    print "%d\t Source 'default'"%(defaultCount)
    print "%d\t Phone #"%(txtedUsCount)
    print "%d\t Confirmed referrals"%(refCount)
    print "%d\t Shared reminders"%(reminderCount)



def getDataForMonth(month):
    if (month < 1 or month > 12):
        print "month must be between 1 and 12"
        return 0
    begin = datetime.datetime(2015, month, 1, 0, 0, 0, tzinfo=pytz.utc)
    end = datetime.datetime(2015, month + 1 % 12, 1, 0, 0, 0, tzinfo=pytz.utc)
    allUsers = User.objects.filter(activated__gt=begin, activated__lt=end)
    countUsers(allUsers)

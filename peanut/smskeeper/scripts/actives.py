from datetime import date, timedelta
from smskeeper.models import Message, User
from smskeeper import keeper_constants

dateFilter = date.today() - timedelta(days=7)

activatedUsersAll= User.objects.filter(activated__lt=dateFilter)
activatedUsersFB = User.objects.filter(activated__lt=dateFilter, signup_data_json__icontains='fb')

usersAll = Message.objects.values('user__name').filter(incoming=True, added__gt=dateFilter, user__activated__lt=dateFilter, user__completed_tutorial=True).distinct()

usersFB = Message.objects.values('user__name').filter(incoming=True, added__gt=dateFilter, user__completed_tutorial=True, user__in=activatedUsersFB, user__signup_data_json__icontains='fb').distinct()

usersStopped = User.objects.filter(activated__lt=dateFilter, state=keeper_constants.STATE_STOPPED)

print "Total users activated: %s (FB: %s)" %(len(activatedUsersAll), len(activatedUsersFB))
print "Active users: %s (FB: %s)"%(len(usersAll), len(usersFB))
print "%% actives: %s%% (FB: %s%%)"%(float(len(usersAll))/float(len(activatedUsersAll))*100.0, float(len(usersFB))/float(len(activatedUsersFB))*100.0)
print "Stopped users: %s"%(len(usersStopped))


# query to get sorted list of incoming count by users

from smskeeper.models import Message
from django.db.models import Count

users = Message.objects.values_list('user__id', 'user__name').filter(incoming=True, user__completed_tutorial=True).annotate(total_incoming=Count('user__id')).order_by('total_incoming')

for entry in users:
    print "%s %s: %s"%(entry[0], entry[1], entry[2])
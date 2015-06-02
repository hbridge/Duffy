from datetime import date, timedelta
from smskeeper.models import Message, User

dateFilter = date.today() - timedelta(days=7)

activatedUsersAll= User.objects.filter(activated__lt=dateFilter)
activatedUsersFB = User.objects.filter(activated__lt=dateFilter, signup_data_json__icontains='fb')

usersAll = Message.objects.values('user__name').filter(incoming=True, added__gt=dateFilter, user__activated__lt=dateFilter, user__completed_tutorial=True).distinct()

usersFB = Message.objects.values('user__name').filter(incoming=True, added__gt=dateFilter, user__completed_tutorial=True, user__in=activatedUsersFB, user__signup_data_json__icontains='fb').distinct()

for i,k in enumerate(usersAll):
    print k

print "Total users activated: %s (FB: %s)" %(len(activatedUsersAll), len(activatedUsersFB))
print "Active users: %s (FB: %s)"%(len(usersAll), len(usersFB))
print "percent actives: %s%% (FB: %s%%)"%(float(len(usersAll))/float(len(activatedUsersAll))*100.0, float(len(usersFB))/float(len(activatedUsersFB))*100.0)

from django.conf.urls import patterns, include, url

from django.contrib import admin
admin.autodiscover()
from smskeeper.ics_feed import EventFeed

urlpatterns = patterns(
	'',
	url(r'^admin/', include(admin.site.urls)),
	url(r'^memfresh/', include('memfresh.urls')),
	url(r'^smskeeper/', include('smskeeper.urls')),
	url(r'^ics/[KP](?P<key>[A-Za-z0-9]+)', EventFeed()),
	url(r'^[KP](?P<key>[A-Za-z0-9]+)', 'smskeeper.views.mykeeper'),  # keys can start with either K or P
	url(r'^ios-notifications/', include('ios_notifications.urls')),
)

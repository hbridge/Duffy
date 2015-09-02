from django.conf.urls import patterns, include, url

from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns(
	'',
	url(r'^admin/', include(admin.site.urls)),
	url(r'^memfresh/', include('memfresh.urls')),
	url(r'^smskeeper/', include('smskeeper.urls')),
	url(r'^ics/K?P?(?P<key>[A-Za-z0-9]+)', 'smskeeper.ics_feed.icsFeed'),
	url(r'^K?P?(?P<key>[A-Za-z0-9]+)', 'smskeeper.views.mykeeper'),  # keys can start with either K or P
	url(r'^ios-notifications/', include('ios_notifications.urls')),
)

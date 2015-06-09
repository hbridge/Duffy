from django.conf.urls import patterns, include, url

from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
    url(r'^admin/', include(admin.site.urls)),

    url(r'^memfresh/', include('memfresh.urls')),
    url(r'^smskeeper/', include('smskeeper.urls')),

    url(r'^k/(?P<key>[A-Za-z0-9]+)', 'smskeeper.views.mykeeper'),

    url(r'^ios-notifications/', include('ios_notifications.urls')),
)

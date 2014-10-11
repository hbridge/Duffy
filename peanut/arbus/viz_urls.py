from django.conf.urls import patterns, url
from arbus import viz_views

urlpatterns = patterns('',
	url(r'^summary', viz_views.userbaseSummary, name='userbaseSummary'),
)
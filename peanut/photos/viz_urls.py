from django.conf.urls import patterns, url
from photos import viz_views

urlpatterns = patterns('',
	url(r'^groups/(?P<user_id>\d+)/$', viz_views.groups, name='groups'),
	url(r'^search/(?P<user_id>\d+)/$', viz_views.search, name='search'),
)
from django.conf.urls import patterns, url
from rest_framework.urlpatterns import format_suffix_patterns

# If you're changing these, don't forget to change them below
from strand import api_views as strand_api_views
from arbus import api_views as arbus_api_views

urlpatterns = patterns('',
	url(r'^get_user', 'arbus.api_views.get_user', {'productId': '1'}),
	url(r'^create_user', 'arbus.api_views.create_user', {'productId': '1'}),
	url(r'^photos/$', arbus_api_views.PhotoAPI.as_view()),
	url(r'^photos/(?P<photoId>[0-9]+)/$', arbus_api_views.PhotoAPI.as_view()),
	url(r'^photos/bulk/$', arbus_api_views.PhotoBulkAPI.as_view()),

	url(r'^neighbors', 'strand.api_views.neighbors'),
	url(r'^get_joinable_strands', 'strand.api_views.get_joinable_strands')
)

urlpatterns = format_suffix_patterns(urlpatterns)
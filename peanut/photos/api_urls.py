from django.conf.urls import patterns, url
from rest_framework.urlpatterns import format_suffix_patterns
from photos import api_views

urlpatterns = patterns('photos.api_views',
	url(r'^addPhoto$', 'add_photo'),
	url(r'^search$', 'search'),
	url(r'^searchJQmobile$', 'searchJQmobile'),
	url(r'^get_suggestions$', 'get_suggestions'),
	url(r'^get_user$', 'get_user'),
	url(r'^create_user$', 'create_user'),

	# REST API
	#url(r'^photos/$', 'photo_list'),
	url(r'^photos/$', api_views.PhotoAPI.as_view()),
	url(r'^photos/(?P<photoId>[0-9]+)/$', api_views.PhotoAPI.as_view())
)

urlpatterns = format_suffix_patterns(urlpatterns)
from django.conf.urls import patterns, url
from photos import api_views

urlpatterns = patterns('',
	url(r'^addPhoto$', api_views.add_photo, name='addPhoto'),
	url(r'^search$', api_views.search, name='search'),
	url(r'^searchJQmobile$', api_views.searchJQmobile, name='searchJQmobile'),
	url(r'^get_suggestions$', api_views.get_suggestions, name='getSuggestions'),
	url(r'^get_user$', api_views.get_user, name="getUser"),
	url(r'^create_user$', api_views.create_user, name="createUser")
)
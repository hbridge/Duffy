from django.conf.urls import patterns, url
from photos import api_views

urlpatterns = patterns('',
	url(r'^addPhoto$', api_views.add_photo, name='addPhoto'),
	url(r'^search$', api_views.search, name='search'),
	url(r'^get_top_locations$', api_views.get_top_locations, name='getTopLocations'),
	url(r'^get_user$', api_views.get_user, name="getUser")
)
from django.conf.urls import patterns, url
from photos import api_views

urlpatterns = patterns('',
	url(r'^addPhoto$', api_views.addPhoto, name='addPhoto'),
	url(r'^manualAddPhoto$', api_views.manualAddPhoto, name='manualAddPhoto'),
	url(r'^search$', api_views.search, name='search')
)
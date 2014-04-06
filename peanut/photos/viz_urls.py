from django.conf.urls import patterns, url
from photos import viz_views

urlpatterns = patterns('',
	url(r'^manualAddPhoto$', viz_views.manualAddPhoto, name='manualAddPhoto'),
	url(r'^groups/(?P<user_id>\d+)/$', viz_views.groups, name='groups'),
	url(r'^search/(?P<user_id>\d+)/$', viz_views.search, name='search'),
	url(r'^gallery/(?P<user_id>\d+)/$', viz_views.gallery, name='gallery'),
	url(r'^search/$', viz_views.search, name='search'),
	url(r'^serve_image/$', viz_views.serveImage, name='serve_image'),
)
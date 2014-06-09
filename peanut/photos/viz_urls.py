from django.conf.urls import patterns, url
from photos import viz_views

urlpatterns = patterns('',
	url(r'^manualAddPhoto$', viz_views.manualAddPhoto, name='manualAddPhoto'),
	url(r'^search$', viz_views.search, name='search'),
	url(r'^summary$', viz_views.userbaseSummary, name='userbaseSummary'),
	url(r'^neighbors$', viz_views.neighbors),
)